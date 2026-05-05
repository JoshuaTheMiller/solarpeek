# frozen_string_literal: true

# Auth0ManagementService
# ─────────────────────────────────────────────────────────────────────────────
# Wraps the Auth0 Management API for user lifecycle operations.
#
# Invitation flow (Option A — Auth0 sends the email):
#   1. `invite_user` creates an Auth0 account for the email address.
#   2. Auth0 dispatches a "set your password" email to the invitee via a
#      password-change ticket. The ticket redirects to FRONTEND_URL after
#      the password is set, so the user can log in immediately.
#
# Management API tokens are cached in Redis for 23 h (tokens expire in 24 h).
#
class Auth0ManagementService
  MGMT_TOKEN_CACHE_KEY = 'auth0:mgmt_token'
  MGMT_TOKEN_CACHE_TTL = 82_800  # 23 hours
  DB_CONNECTION        = 'Username-Password-Authentication'
  INVITATION_TTL_SECS  = 604_800 # 7 days

  # Creates an Auth0 user and sends them an invitation email.
  #
  # @param email      [String]
  # @param result_url [String] Redirect URL after the user sets their password
  # @return           [String] The Auth0 user_id (sub) of the created user
  def self.invite_user(email:, result_url: nil)
    result_url ||= ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    user          = create_auth0_user(email: email)
    send_invitation_ticket(user_id: user['user_id'], result_url: result_url)
    user['user_id']
  end

  # Blocks a user in Auth0 (soft-deactivation — they cannot log in).
  def self.deactivate_user(auth0_sub:)
    patch_user(auth0_sub: auth0_sub, body: { blocked: true })
  end

  # Unblocks a user in Auth0.
  def self.reactivate_user(auth0_sub:)
    patch_user(auth0_sub: auth0_sub, body: { blocked: false })
  end

  # ── Private ────────────────────────────────────────────────────────────────
  private_class_method def self.create_auth0_user(email:)
    response = mgmt_request(
      method: :post,
      path:   '/users',
      body:   {
        connection:     DB_CONNECTION,
        email:          email,
        password:       SecureRandom.hex(24), # random; overridden by invitation ticket
        email_verified: false,
        verify_email:   false
      }
    )
    raise "Auth0 user creation failed (#{response.code}): #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  private_class_method def self.send_invitation_ticket(user_id:, result_url:)
    response = mgmt_request(
      method: :post,
      path:   '/tickets/password-change',
      body:   {
        user_id:                 user_id,
        result_url:              result_url,
        ttl_sec:                 INVITATION_TTL_SECS,
        mark_email_as_verified:  true
      }
    )
    raise "Auth0 invitation ticket failed (#{response.code}): #{response.body}" unless response.success?

    JSON.parse(response.body)['ticket']
  end

  private_class_method def self.patch_user(auth0_sub:, body:)
    encoded_sub = URI.encode_www_form_component(auth0_sub)
    response    = mgmt_request(method: :patch, path: "/users/#{encoded_sub}", body: body)
    raise "Auth0 user update failed (#{response.code}): #{response.body}" unless response.success?
  end

  private_class_method def self.mgmt_request(method:, path:, body: nil)
    HTTParty.send(
      method,
      "https://#{ENV.fetch('AUTH0_DOMAIN')}/api/v2#{path}",
      headers: {
        'Authorization' => "Bearer #{management_api_token}",
        'Content-Type'  => 'application/json'
      },
      body: body&.to_json
    )
  end

  # Fetches (or returns cached) a Management API access token.
  private_class_method def self.management_api_token
    cached = $redis&.get(MGMT_TOKEN_CACHE_KEY)
    return cached if cached

    response = HTTParty.post(
      "https://#{ENV.fetch('AUTH0_DOMAIN')}/oauth/token",
      headers: { 'Content-Type' => 'application/json' },
      body: {
        grant_type:    'client_credentials',
        client_id:     ENV.fetch('AUTH0_MANAGEMENT_CLIENT_ID'),
        client_secret: ENV.fetch('AUTH0_MANAGEMENT_CLIENT_SECRET'),
        audience:      ENV.fetch('AUTH0_MANAGEMENT_AUDIENCE')
      }.to_json
    )

    raise "Failed to obtain Auth0 management token (#{response.code})" unless response.success?

    token = JSON.parse(response.body)['access_token']
    $redis&.setex(MGMT_TOKEN_CACHE_KEY, MGMT_TOKEN_CACHE_TTL, token)
    token
  end
end
