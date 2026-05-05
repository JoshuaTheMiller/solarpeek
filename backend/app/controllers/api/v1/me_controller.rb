# frozen_string_literal: true

module Api
  module V1
    class MeController < BaseController
      # GET /api/v1/me
      # Returns the current authenticated user's profile and query limit.
      # The frontend displays query_limit_days prominently on the solar trends page.
      def show
        render_json(serialize_user(current_user))
      end

      private

      def serialize_user(user)
        payload = {
          id:               user.id,
          email:            user.email,
          role:             user.role,
          query_limit_days: user.query_limit_days,
          active:           user.active,
          created_at:       user.created_at
        }
        # Let the frontend know bypass mode is active so it can show a warning banner.
        payload[:bypass_mode] = true if auth_bypass_enabled?
        payload
      end
    end
  end
end
