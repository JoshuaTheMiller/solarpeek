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

      # PATCH /api/v1/me/preferences
      # Accepts: { query_limit_banner_dismissed: Boolean }
      def update_preferences
        current_user.update!(preferences_params)
        render_json(serialize_user(current_user))
      end

      private

      def preferences_params
        params.require(:preferences).permit(:query_limit_banner_dismissed)
      end

      def serialize_user(user)
        payload = {
          id:                            user.id,
          email:                         user.email,
          role:                          user.role,
          query_limit_days:              user.query_limit_days,
          active:                        user.active,
          created_at:                    user.created_at,
          query_limit_banner_dismissed:  user.query_limit_banner_dismissed
        }
        # Let the frontend know bypass mode is active so it can show a warning banner.
        payload[:bypass_mode] = true if auth_bypass_enabled?
        payload
      end
    end
  end
end
