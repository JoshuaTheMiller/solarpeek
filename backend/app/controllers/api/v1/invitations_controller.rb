# frozen_string_literal: true

module Api
  module V1
    class InvitationsController < BaseController
      # POST /api/v1/invitations
      #
      # Invites a new user by:
      #   1. Checking the current user has permission to invite with the given role
      #   2. Creating the Auth0 account + dispatching a password-setup email
      #   3. Creating the User record in the local DB
      #
      # Body: { email: String, role: "admin"|"manager"|"viewer" }
      #
      # Roles a caller can invite:
      #   admin   → admin, manager, viewer
      #   manager → manager, viewer
      #   viewer  → (cannot invite)
      def create
        email = invitation_params[:email].to_s.strip.downcase
        role  = invitation_params[:role].to_s

        # Role-hierarchy check
        unless current_user.can_invite_role?(role)
          return render_error(:forbidden,
            "#{current_user.role.capitalize}s cannot invite users with role '#{role}'")
        end

        # Validate role is a known value before touching Auth0
        unless User.roles.key?(role)
          return render_error(:unprocessable_entity, "Unknown role: #{role}")
        end

        # Prevent duplicate invitations
        if User.exists?(email: email)
          return render_error(:unprocessable_entity, "A user with that email already exists")
        end

        # Wrap Auth0 creation + DB record in a transaction so a DB failure
        # doesn't leave an orphaned Auth0 account (and vice versa).
        auth0_sub = nil
        user      = nil

        ActiveRecord::Base.transaction do
          result_url = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/dashboard"
          auth0_sub  = Auth0ManagementService.invite_user(email: email, result_url: result_url)

          user = User.create!(
            auth0_sub:        auth0_sub,
            email:            email,
            role:             role,
            query_limit_days: 30,   # default; can be changed after invite
            active:           true,
            invited_by:       current_user
          )
        end

        render_json(serialize_user(user), status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error(:unprocessable_entity, e.record.errors.full_messages)
      rescue StandardError => e
        Rails.logger.error "Invitation failed for #{email}: #{e.message}"
        render_error(:unprocessable_entity, "Invitation failed: #{e.message}")
      end

      private

      def invitation_params
        params.require(:invitation).permit(:email, :role)
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
    end
  end
end
