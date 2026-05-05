# frozen_string_literal: true

# =============================================================================
# Auth Bypass Guard
# =============================================================================
# Checked at startup. When BOTH env vars are present, authentication is skipped
# and all requests are treated as the local dev admin user.
#
# To enable:
#   DISABLE_AUTH=true
#   AM_I_SURE=yes
#
# Both variables must be set together — neither alone has any effect.
# Bypass is categorically blocked in production.
# =============================================================================

disable_auth = ENV.fetch('DISABLE_AUTH', '').strip.downcase == 'true'
am_i_sure    = ENV.fetch('AM_I_SURE',    '').strip.downcase == 'yes'

if disable_auth && am_i_sure
  if Rails.env.production?
    raise <<~MSG

      ══════════════════════════════════════════════════════════════════════
      FATAL: DISABLE_AUTH + AM_I_SURE bypass is NOT permitted in production.
      Remove DISABLE_AUTH and AM_I_SURE from your environment immediately.
      ══════════════════════════════════════════════════════════════════════
    MSG
  end

  # Print to STDOUT so it is visible even when log level filters logger output
  banner = <<~BANNER

    ╔══════════════════════════════════════════════════════════════════╗
    ║  ⚠   AUTHENTICATION BYPASS IS ACTIVE                           ║
    ║                                                                  ║
    ║   DISABLE_AUTH=true  +  AM_I_SURE=yes                          ║
    ║                                                                  ║
    ║   • Auth0 is NOT required — JWT validation is skipped           ║
    ║   • Every request is authenticated as dev@localhost (admin)     ║
    ║   • Do NOT use in staging or production                         ║
    ╚══════════════════════════════════════════════════════════════════╝
  BANNER

  $stdout.puts banner
  Rails.logger.warn banner

elsif disable_auth && !am_i_sure
  # Partial set — warn loudly so the developer knows it won't take effect
  $stdout.puts "\n⚠  DISABLE_AUTH=true is set but AM_I_SURE=yes is missing. " \
               "Authentication is still ACTIVE.\n\n"

elsif !disable_auth && am_i_sure
  $stdout.puts "\n⚠  AM_I_SURE=yes is set but DISABLE_AUTH=true is missing. " \
               "Authentication is still ACTIVE.\n\n"
end
