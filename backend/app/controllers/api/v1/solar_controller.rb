# frozen_string_literal: true

module Api
  module V1
    class SolarController < BaseController
      # GET /api/v1/solar/readings
      #
      # Returns hourly wattage readings for the requested date range.
      # start_date and end_date are optional; when omitted they default to
      # (today - 364 days) and today respectively, covering a rolling year.
      # "today" may be computed in a caller-provided IANA timezone.
      # The range is validated against the current user's query_limit_days
      # by SolarPolicy before the service is called.
      #
      # Response shape:
      #   {
      #     data: [{ timestamp: "ISO8601", wattage: Float }, ...],
      #     best_readings: [{ timestamp: "ISO8601", wattage: Float }, ...],
      #     best_date: "YYYY-MM-DD" | nil,
      #     worst_readings: [{ timestamp: "ISO8601", wattage: Float }, ...],
      #     worst_date: "YYYY-MM-DD" | nil,
      #     today_readings: [{ timestamp: "ISO8601", wattage: Float }, ...],
      #     today_date: "YYYY-MM-DD",
      #     meta: { query_limit_days: Integer, requested_days: Integer }
      #   }
      def readings
        timezone = parse_timezone(:timezone)
        today_date = Time.current.in_time_zone(timezone).to_date

        start_date = parse_date(:start_date, default: today_date - 364)
        end_date   = parse_date(:end_date,   default: today_date)
        return_best_day  = parse_boolean(:return_best_day)
        return_worst_day = parse_boolean(:return_worst_day)
        return_today     = parse_boolean(:return_today)

        # Pundit checks query_limit_days and date ordering
        authorize SolarQuery.new(
          start_date: start_date,
          end_date: end_date,
          return_best_day: return_best_day,
          return_worst_day: return_worst_day,
          return_today: return_today
        ),
                  policy_class: SolarPolicy

        result = SolarDataService.fetch(
          start_date: start_date,
          end_date: end_date,
          return_best_day: return_best_day,
          return_worst_day: return_worst_day,
          return_today: return_today,
          today_date: today_date
        )

        render_json(
          result.fetch(:readings),
          meta: {
            query_limit_days: current_user.query_limit_days,
            requested_days:   (end_date - start_date).to_i + 1
          },
          extra: {
            best_readings: result.fetch(:best_readings),
            best_date: result.fetch(:best_date),
            worst_readings: result.fetch(:worst_readings),
            worst_date: result.fetch(:worst_date),
            today_readings: result.fetch(:today_readings),
            today_date: result.fetch(:today_date)
          }
        )
      rescue ArgumentError => e
        render_error(:unprocessable_entity, e.message)
      end

      private

      def parse_date(param, default: nil)
        raw = params[param]
        return default if raw.nil? || raw.to_s.strip.empty?

        Date.parse(raw.to_s)
      rescue Date::Error
        raise ArgumentError, "#{param} must be a valid date (YYYY-MM-DD), got: #{params[param].inspect}"
      end

      def parse_boolean(param, default: false)
        raw = params[param]
        return default if raw.nil?

        stripped = raw.to_s.strip
        return default if stripped.empty?

        case stripped.downcase
        when 'true', '1', 'yes', 'on'
          true
        when 'false', '0', 'no', 'off'
          false
        else
          raise ArgumentError, "#{param} must be a boolean value, got: #{raw.inspect}"
        end
      end

      def parse_timezone(param)
        raw = params[param]
        return Time.zone if raw.nil? || raw.to_s.strip.empty?

        zone = ActiveSupport::TimeZone[raw.to_s]
        raise ArgumentError, "#{param} must be a valid IANA timezone, got: #{raw.inspect}" unless zone

        zone
      end
    end
  end
end
