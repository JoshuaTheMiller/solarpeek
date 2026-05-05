# frozen_string_literal: true

# Global Redis client — available as $redis throughout the app.
# Used for:
#   - JWKS key caching     (JsonWebToken service)
#   - Solar readings cache (SolarDataService)
#   - Auth0 mgmt token cache (Auth0ManagementService)

$redis = Redis.new(
  url:            ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  connect_timeout: 5,
  read_timeout:    3,
  write_timeout:   3
)

# Verify connection on boot (raises in dev/test if Redis is unreachable)
begin
  $redis.ping
rescue Redis::CannotConnectError => e
  Rails.logger.warn "Redis unavailable: #{e.message}. Caching will be disabled."
  $redis = nil
end
