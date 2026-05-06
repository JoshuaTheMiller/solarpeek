# frozen_string_literal: true

# SolarDataService
# ─────────────────────────────────────────────────────────────────────────────
# Fetches historical solar generation data for a given date range.
#
# Current implementation: STUB — generates realistic-looking data locally.
# Replace `fetch_from_api` with a real HTTP call once the upstream API is
# defined. The public interface (`SolarDataService.fetch`) and return shape
# will not change.
#
# Return format:
#   {
#     readings: [
#       { timestamp: "2024-06-15T09:00:00Z", wattage: 1234.56 },
#       ...
#     ],
#     best_readings: [...],
#     best_date: "YYYY-MM-DD" | nil,
#     worst_readings: [...],
#     worst_date: "YYYY-MM-DD" | nil,
#     today_readings: [...]
#     today_date: "YYYY-MM-DD"
#   }
#
# Caching:
#   Results are cached in Redis for CACHE_TTL seconds, keyed by date range.
#   Cache is bypassed when Redis is unavailable (graceful degradation).
#
class SolarDataService
  API_PATH = '/index.php/realtimedata/old_power_graph'
  CACHE_VERSION = 'v2'.freeze
  DATE_INDEX_PREFIX = "solar:#{CACHE_VERSION}:date".freeze
  DATE_FETCHED_PREFIX = "solar:#{CACHE_VERSION}:date-fetched".freeze
  POINT_PREFIX = "solar:#{CACHE_VERSION}:point".freeze

  # @param start_date [Date, String]
  # @param end_date   [Date, String]
  # @param return_best_day [Boolean]
  # @param return_worst_day [Boolean]
  # @param return_today [Boolean]
  # @param today_date [Date, String]
  # @return [Hash]
  def self.fetch(start_date:, end_date:, return_best_day: false, return_worst_day: false, return_today: false,
                 today_date: Date.current)
    start_d = start_date.to_date
    end_d   = end_date.to_date
    today_d = today_date.to_date

    points = []
    points_by_requested_date = {}

    (start_d..end_d).each do |date|
      day_points = cached_points_for_date(date)

      if day_points.nil?
        begin
          fetched = fetch_from_api(date: date)
        rescue StandardError
          fetched = []
        end
        cache_points_for_date(date, fetched)
        day_points = fetched.map { |p| p.slice(:timestamp, :wattage) }
      end

      points.concat(day_points)
      points_by_requested_date[date] = day_points
    end

    readings = points.sort_by { |p| p[:timestamp] }

    best_day = return_best_day ? best_day_payload(points_by_requested_date) : nil
    worst_day = return_worst_day ? worst_day_payload(points_by_requested_date) : nil

    {
      readings: readings,
      best_readings: best_day ? best_day.fetch(:readings) : [],
      best_date: best_day ? best_day.fetch(:date).iso8601 : nil,
      worst_readings: worst_day ? worst_day.fetch(:readings) : [],
      worst_date: worst_day ? worst_day.fetch(:date).iso8601 : nil,
      today_readings: return_today ? points_by_requested_date.fetch(today_d, []) : [],
      today_date: today_d.iso8601
    }
  end

  # ── Private ────────────────────────────────────────────────────────────────
  private_class_method def self.date_index_key(date)
    "#{DATE_INDEX_PREFIX}:#{date}:points"
  end

  private_class_method def self.date_fetched_key(date)
    "#{DATE_FETCHED_PREFIX}:#{date}"
  end

  private_class_method def self.point_key(time_ms)
    "#{POINT_PREFIX}:#{time_ms}"
  end

  private_class_method def self.cached_points_for_date(date)
    return nil unless $redis

    if $redis.get(date_fetched_key(date))
      time_ms_list = $redis.zrange(date_index_key(date), 0, -1)
      return [] if time_ms_list.empty?
    end

    time_ms_list = $redis.zrange(date_index_key(date), 0, -1)
    return nil if time_ms_list.empty?

    payloads = $redis.mget(*time_ms_list.map { |time_ms| point_key(time_ms) })
    return nil if payloads.any?(&:nil?)

    payloads
      .map { |payload| JSON.parse(payload, symbolize_names: true).slice(:timestamp, :wattage) }
      .sort_by { |point| point[:timestamp] }
  rescue Redis::BaseError => e
    Rails.logger.warn("Redis read failed for solar cache: #{e.message}")
    nil
  end

  private_class_method def self.cache_points_for_date(date, points)
    return unless $redis

    index_key = date_index_key(date)

    $redis.pipelined do |pipe|
      pipe.set(date_fetched_key(date), '1')
      points.each do |point|
        time_ms = point.fetch(:time_ms)
        pipe.set(
          point_key(time_ms),
          {
            timestamp: point.fetch(:timestamp),
            wattage: point.fetch(:wattage)
          }.to_json
        )
        pipe.zadd(index_key, time_ms, time_ms)
      end
    end
  rescue Redis::BaseError => e
    Rails.logger.warn("Redis write failed for solar cache: #{e.message}")
  end

  # Fetches one day of solar readings from the upstream API.
  # @param date [Date]
  # @return [Array<Hash>]
  private_class_method def self.fetch_from_api(date:)
    base_url = ENV.fetch('HOST')
    url = build_api_url(base_url)

    headers = {
      'Host' => 'SolarInspector',
      'Content-Type' => 'application/x-www-form-urlencoded',
      'x-requested-with' => 'XMLHttpRequest'
    }

    body = URI.encode_www_form(date: date.iso8601)

    response = HTTParty.post(url, body:, headers:)
    raise "Solar API error: #{response.code}" unless response.success?

    payload = response.parsed_response
    payload = JSON.parse(payload) if payload.is_a?(String)
    power_rows = payload.fetch('power')

    power_rows.map do |row|
      time_ms = Integer(row.fetch('time'))

      {
        time_ms:,
        timestamp: Time.at(time_ms / 1000.0).utc.iso8601,
        # Upstream each_system_power is already in watts.
        wattage: row.fetch('each_system_power').to_f.round(2)
      }
    end
  rescue KeyError, TypeError, ArgumentError => e
    raise "Solar API response format error: #{e.message}"
  end

  private_class_method def self.build_api_url(base_url)
    normalized = base_url.to_s.strip
    raise ArgumentError, 'HOST cannot be blank' if normalized.empty?

    normalized = "http://#{normalized}" unless normalized.match?(%r{\Ahttps?://}i)

    uri = URI.parse(normalized)
    host_and_port = uri.host
    host_and_port = "#{host_and_port}:#{uri.port}" if uri.port && ![80, 443].include?(uri.port)

    # If HOST already contains API_PATH, reuse it as-is.
    path = uri.path.to_s
    if path.end_with?(API_PATH)
      final_path = path
    else
      # Strip any trailing slash and append the required API path exactly once.
      final_path = "#{path.sub(%r{/+\z}, '')}#{API_PATH}"
    end

    "#{uri.scheme}://#{host_and_port}#{final_path}"
  rescue URI::InvalidURIError => e
    raise ArgumentError, "Invalid HOST value: #{e.message}"
  end

  private_class_method def self.best_day_payload(grouped_by_date)
    days_with_generation = days_with_generation(grouped_by_date)
    return nil if days_with_generation.empty?

    date, readings = days_with_generation.max_by { |_day, points| daily_total(points) }
    { date: date, readings: readings || [] }
  end

  private_class_method def self.worst_day_payload(grouped_by_date)
    days_with_generation = days_with_generation(grouped_by_date)
    return nil if days_with_generation.empty?

    date, readings = days_with_generation.min_by { |_day, points| daily_total(points) }
    { date: date, readings: readings || [] }
  end

  private_class_method def self.days_with_generation(grouped_by_date)
    grouped_by_date.reject { |_day, points| daily_total(points).zero? }
  end

  private_class_method def self.daily_total(points)
    points.sum { |point| point.fetch(:wattage).to_f }
  end
end
