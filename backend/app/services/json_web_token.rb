# frozen_string_literal: true

require 'net/http'

# Verifies Auth0 JWTs using the RS256 algorithm and the tenant's JWKS endpoint.
# Public keys are cached in Redis to avoid fetching JWKS on every request.
#
# Usage:
#   payload, _header = JsonWebToken.verify(token)
#   payload['sub']  # => "auth0|abc123"
#
class JsonWebToken
  JWKS_CACHE_KEY = 'auth0:jwks'
  JWKS_CACHE_TTL = 3600 # 1 hour

  # Decodes and verifies the JWT. Returns [payload, header] on success.
  # Raises JWT::DecodeError (or subclass) on any failure.
  def self.verify(token)
    JWT.decode(
      token,
      nil,              # key is resolved via the block below
      true,             # verify signature
      algorithms:   ['RS256'],
      iss:          "https://#{ENV.fetch('AUTH0_DOMAIN')}/",
      verify_iss:   true,
      aud:          ENV.fetch('AUTH0_AUDIENCE'),
      verify_aud:   true,
      verify_expiration: true
    ) do |header, _payload|
      public_key_for(header['kid'])
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────
  private_class_method def self.public_key_for(kid)
    jwks = cached_jwks
    jwk  = jwks.find { |k| k['kid'] == kid }
    raise JWT::DecodeError, "No JWK found for kid=#{kid}. JWKS may be stale." unless jwk

    JWT::JWK.import(jwk.transform_keys(&:to_sym)).public_key
  end

  private_class_method def self.cached_jwks
    raw = $redis&.get(JWKS_CACHE_KEY)
    return JSON.parse(raw) if raw

    keys = fetch_jwks
    $redis&.setex(JWKS_CACHE_KEY, JWKS_CACHE_TTL, keys.to_json)
    keys
  end

  private_class_method def self.fetch_jwks
    uri      = URI("https://#{ENV.fetch('AUTH0_DOMAIN')}/.well-known/jwks.json")
    response = Net::HTTP.get_response(uri)
    raise "JWKS fetch failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch('keys')
  end
end
