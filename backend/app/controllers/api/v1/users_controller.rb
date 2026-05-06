# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      before_action :set_user, only: %i[show destroy query_limit reactivate]

      # GET /api/v1/users
      def index
        authorize User
        users = policy_scope(User).order(created_at: :desc)
        render_json(users.map { |u| serialize_user(u) })
      end

      # GET /api/v1/users/:id
      def show
        authorize @user
        render_json(serialize_user(@user))
      end

      # DELETE /api/v1/users/:id
      # Deactivates the user (soft-delete). Also blocks them in Auth0.
      def destroy
        authorize @user

        ActiveRecord::Base.transaction do
          @user.update!(active: false)
          Auth0ManagementService.deactivate_user(auth0_sub: @user.auth0_sub)
        end

        render_json(serialize_user(@user))
      rescue StandardError => e
        render_error(:unprocessable_entity, "Deactivation failed: #{e.message}")
      end

      # PATCH /api/v1/users/:id/reactivate
      # Reactivates a previously deactivated user.
      def reactivate
        authorize @user, :reactivate?

        ActiveRecord::Base.transaction do
          @user.update!(active: true)
          Auth0ManagementService.reactivate_user(auth0_sub: @user.auth0_sub)
        end

        render_json(serialize_user(@user))
      rescue StandardError => e
        render_error(:unprocessable_entity, "Reactivation failed: #{e.message}")
      end

      # PATCH /api/v1/users/:id/query_limit
      # Sets the query_limit_days for the specified user.
      # Body: { query_limit_days: Integer }
      def query_limit
        authorize @user, :query_limit?

        days = params.require(:query_limit_days).to_i
        unless days.positive?
          return render_error(:unprocessable_entity, 'query_limit_days must be a positive integer')
        end

        max_days = query_limit_hard_max_days
        if days > max_days
          return render json: {
            error: "query_limit_days cannot exceed #{max_days} days. Set it to #{max_days} or contact the real admin for more information.",
            error_code: 'query_limit_exceeds_hard_max',
            max_query_limit_days: max_days
          }, status: :unprocessable_entity
        end

        @user.update!(query_limit_days: days)

        # Invalidate any cached solar responses for this user
        invalidate_user_solar_cache(@user)

        render_json(serialize_user(@user))
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def serialize_user(user)
        {
          id:               user.id,
          email:            user.email,
          role:             user.role,
          query_limit_days: user.query_limit_days,
          active:           user.active,
          invited_by_id:    user.invited_by_id,
          created_at:       user.created_at
        }
      end

      # Invalidate any solar cache entries that included this user's limit
      # as part of the cache key. (Simple: clear all solar caches for safety.)
      def invalidate_user_solar_cache(_user)
        keys = $redis&.keys('solar:readings:*')
        $redis&.del(*keys) if keys&.any?
      end

      # System-wide maximum query limit days. Default is 90 when unset/invalid.
      def query_limit_hard_max_days
        configured = ENV.fetch('MAX_QUERY_LIMIT_DAYS', '90').to_i
        configured.positive? ? configured : 90
      end
    end
  end
end
