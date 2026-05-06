# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid,  with: :handle_unprocessable

  attr_reader :current_user

  private

  # ── Authentication ──────────────────────────────────────────────────────────

  def authenticate_user!
    # Bypass mode: skip Auth0 entirely and use a local dev admin user.
    # Requires BOTH DISABLE_AUTH=true AND AM_I_SURE=yes to be set.
    # Never active in production (blocked by config/initializers/bypass_auth.rb).
    if auth_bypass_enabled?
      @current_user = bypass_user
      return
    end

    token = extract_bearer_token
    return render_error(:unauthorized, 'No token provided') unless token

    payload, = JsonWebToken.verify(token)
    @current_user = User.active.find_by(auth0_sub: payload['sub'])

    render_error(:unauthorized, 'User not found or inactive') unless @current_user
  rescue JWT::ExpiredSignature
    render_error(:unauthorized, 'Token has expired')
  rescue JWT::DecodeError => e
    render_error(:unauthorized, "Invalid token: #{e.message}")
  end

  # Returns true only when BOTH kill-switches are set AND we are not in production.
  def auth_bypass_enabled?
    return false if Rails.env.production?

    ENV.fetch('DISABLE_AUTH', '').strip.downcase == 'true' &&
      ENV.fetch('AM_I_SURE',  '').strip.downcase == 'yes'
  end

  # Finds or creates a stable local admin user used in bypass mode.
  # Uses a clearly fake auth0_sub so it is never confused with a real identity.
  # Attributes are kept in sync on every call so DB drift does not cause surprises.
  def bypass_user
    user = User.find_or_initialize_by(auth0_sub: 'dev|bypass-user')
    user.assign_attributes(
      email:            'dev@localhost',
      role:             'admin',
      query_limit_days: 365,
      active:           true
    )
    user.save! if user.changed?
    user
  end

  def extract_bearer_token
    header = request.headers['Authorization']
    return nil unless header&.start_with?('Bearer ')

    header.split(' ', 2).last.presence
  end

  # ── Pundit helpers ──────────────────────────────────────────────────────────

  # Pundit calls this to get the current user for policy checks
  def pundit_user = current_user

  # ── Error handlers ──────────────────────────────────────────────────────────

  def handle_unauthorized(err)
    render_error(:forbidden, err.message.presence || 'Not authorized')
  end

  def handle_not_found(err)
    render_error(:not_found, err.message)
  end

  def handle_unprocessable(err)
    render_error(:unprocessable_entity, err.record.errors.full_messages)
  end

  def render_error(status, message)
    render json: { error: message }, status: status
  end
end
