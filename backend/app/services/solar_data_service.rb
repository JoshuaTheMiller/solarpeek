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
#   [
#     { timestamp: "2024-06-15T09:00:00Z", wattage: 1234.56 },
#     ...
#   ]
#
# Caching:
#   Results are cached in Redis for CACHE_TTL seconds, keyed by date range.
#   Cache is bypassed when Redis is unavailable (graceful degradation).
#
class SolarDataService
  CACHE_TTL = 600 # 10 minutes

  # @param start_date [Date, String]
  # @param end_date   [Date, String]
  # @return [Array<Hash>]
  def self.fetch(start_date:, end_date:)
    start_d = start_date.to_date
    end_d   = end_date.to_date

    cache_key = "solar:readings:#{start_d}:#{end_d}"

    if (raw = $redis&.get(cache_key))
      return JSON.parse(raw, symbolize_names: true)
    end

    # ── TODO: Replace with real API call ─────────────────────────────────────
    # data = fetch_from_api(start_date: start_d, end_date: end_d)
    data = generate_stub_data(start_d, end_d)

    $redis&.setex(cache_key, CACHE_TTL, data.to_json)
    data
  end

  # ── Private ────────────────────────────────────────────────────────────────
  private_class_method def self.generate_stub_data(start_date, end_date)
    data    = []
    current = start_date

    while current <= end_date
      # Hourly readings covering daylight hours (06:00–20:00 UTC)
      (6..20).each do |hour|
        # Approximate a bell-curve centred on solar noon (13:00)
        peak_hour = 13.0
        sigma     = 3.5
        gaussian  = Math.exp(-((hour - peak_hour)**2) / (2 * sigma**2))

        base    = 6_000 * gaussian   # ~6 kW peak system
        jitter  = rand(-300.0..300.0)
        wattage = [base + jitter, 0.0].max.round(2)

        data << {
          timestamp: Time.utc(current.year, current.month, current.day, hour).iso8601,
          wattage:   wattage
        }
      end

      current += 1
    end

    data
  end

  # Placeholder for the real upstream API call.
  # @param start_date [Date]
  # @param end_date   [Date]
  # @return [Array<Hash>]
  private_class_method def self.fetch_from_api(start_date:, end_date:)
    # response = HTTParty.get(
    #   ENV.fetch('SOLAR_API_URL'),
    #   query: { start: start_date.iso8601, end: end_date.iso8601 },
    #   headers: { 'Authorization' => "Bearer #{ENV.fetch('SOLAR_API_KEY')}" }
    # )
    # raise "Solar API error: #{response.code}" unless response.success?
    # response.parsed_response['data'].map { |d| d.slice('timestamp', 'wattage').symbolize_keys }
    raise NotImplementedError, 'Real solar API not yet configured'
  end
end
