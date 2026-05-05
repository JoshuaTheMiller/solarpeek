# frozen_string_literal: true

module Api
  module V1
    class SolarController < BaseController
      # GET /api/v1/solar/readings?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
      #
      # Returns hourly wattage readings for the requested date range.
      # The range is validated against the current user's query_limit_days
      # by SolarPolicy before the service is called.
      #
      # Response shape:
      #   {
      #     data: [{ timestamp: "ISO8601", wattage: Float }, ...],
      #     meta: { query_limit_days: Integer, requested_days: Integer }
      #   }
      def readings
        start_date = parse_date(:start_date)
        end_date   = parse_date(:end_date)

        # Pundit checks query_limit_days and date ordering
        authorize SolarQuery.new(start_date: start_date, end_date: end_date),
                  policy_class: SolarPolicy

        data = SolarDataService.fetch(start_date: start_date, end_date: end_date)

        render_json(
          data,
          meta: {
            query_limit_days: current_user.query_limit_days,
            requested_days:   (end_date - start_date).to_i + 1
          }
        )
      rescue ArgumentError => e
        render_error(:unprocessable_entity, e.message)
      end

      private

      def parse_date(param)
        raw = params.require(param)
        Date.parse(raw.to_s)
      rescue Date::Error
        raise ArgumentError, "#{param} must be a valid date (YYYY-MM-DD), got: #{params[param].inspect}"
      end
    end
  end
end
