#!/usr/bin/env ruby
# frozen_string_literal: true

# =============================================================================
# SolarPeak — Auth0 Initial Configuration Script
# =============================================================================
#
# This script automates the initial Auth0 setup for the SolarPeak application.
# It uses the Auth0 Management API to create and wire up all required resources,
# then writes ready-to-use .env files for both the Rails backend and Next.js
# frontend.
#
# ─── Manual Prerequisites (do these ONCE in the Auth0 Dashboard) ─────────────
#
#  1. Create a free Auth0 account at https://auth0.com
#
#  2. Create a new tenant — recommended name: "solarpeak-dev"
#     (Top-right avatar menu → Create tenant)
#
#  3. Create a Bootstrap M2M application:
#       Dashboard → Applications → Applications → Create Application
#       → Name:  "SolarPeak Bootstrap"
#       → Type:  Machine to Machine Applications  → Click Create
#       → API:   Auth0 Management API             → Click Authorize
#       → Permissions: click "All" to select all scopes → click Authorize
#
#  4. Open the Bootstrap app's Settings tab and note:
#       • Domain         (e.g.  dev-abc123.us.auth0.com)
#       • Client ID
#       • Client Secret
#
#  5. Run this script from the project root:
#       ruby scripts/auth0_setup.rb
#
# ─── What This Script Creates ─────────────────────────────────────────────────
#
#   Auth0 resources
#   ├── SolarPeak Web       — SPA application (Next.js, Auth Code + PKCE)
#   ├── SolarPeak API       — API resource server (JWT audience for Rails)
#   └── SolarPeak Backend   — M2M app (Rails → Management API for invitations)
#
#   Local files
#   ├── backend/.env              ← Rails secrets  (gitignored)
#   ├── frontend/.env.local       ← Next.js secrets (gitignored)
#   ├── backend/.env.example      ← Safe to commit
#   └── frontend/.env.example     ← Safe to commit
#
# ─── User Invitation Flow (Option A — Auth0 sends the email) ─────────────────
#
#   When an admin or manager invites a user via the Rails API:
#
#   1. Rails calls POST /api/v2/users  (Auth0 Management API)
#      → Creates the user account with email_verified: false
#
#   2. Rails calls POST /api/v2/tickets/password-change
#      → Auth0 emails the invitee a "Set your password" link
#      → result_url redirects back to the SolarPeak app after password is set
#
#   3. Invitee clicks the email link, sets their password on Auth0's
#      hosted page, and is redirected to SolarPeak where they log in normally.
#
#   The M2M credentials written to backend/.env are what Rails uses to
#   obtain a Management API token for steps 1 and 2 above.
#
# =============================================================================

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'
require 'fileutils'

# ─── Terminal helpers ──────────────────────────────────────────────────────────

def colorize(text, code) = "\e[#{code}m#{text}\e[0m"
def green(t)  = colorize(t, 32)
def red(t)    = colorize(t, 31)
def yellow(t) = colorize(t, 33)
def bold(t)   = colorize(t, 1)
def dim(t)    = colorize(t, 2)

def prompt(label, default: nil, secret: false)
  suffix = default ? " [#{dim(default)}]" : ''
  print "  #{label}#{suffix}: "
  $stdout.flush

  value =
    if secret
      begin
        require 'io/console'
        v = $stdin.noecho(&:gets).to_s.chomp
        puts
        v
      rescue LoadError
        gets.to_s.chomp
      end
    else
      gets.to_s.chomp
    end

  value.empty? ? default.to_s : value
end

def step(n, total, label)
  puts
  puts bold("  Step #{n}/#{total} · #{label}")
end

def ok(msg)       = puts("    #{green('✓')} #{msg}")
def warn_msg(msg) = puts("    #{yellow('⚠')} #{msg}")
def fail!(msg)
  puts("    #{red('✗')} #{msg}")
  exit 1
end

# ─── HTTP helpers ──────────────────────────────────────────────────────────────

# Generic HTTP request. Returns [status_code (Integer), parsed_body (Hash/Array/nil)].
def http_json(method:, url:, headers: {}, body: nil)
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = (uri.scheme == 'https')
  http.read_timeout = 20

  klass   = { 'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post,
               'PATCH' => Net::HTTP::Patch, 'DELETE' => Net::HTTP::Delete }
  request = klass.fetch(method.upcase) { fail!("Unknown method: #{method}") }
             .new(uri.request_uri)

  headers.each { |k, v| request[k] = v }
  if body
    request['Content-Type'] = 'application/json'
    request.body = body.to_json
  end

  response = http.request(request)
  parsed   = JSON.parse(response.body) rescue nil
  [response.code.to_i, parsed]
end

# Authenticated Management API call. Exits on non-2xx.
def mgmt(method:, path:, token:, domain:, body: nil)
  url           = "https://#{domain}/api/v2#{path}"
  status, parsed = http_json(
    method:  method,
    url:     url,
    headers: { 'Authorization' => "Bearer #{token}" },
    body:    body
  )

  unless status.between?(200, 299)
    puts
    puts red("  Management API error: #{method} #{path} → HTTP #{status}")
    puts dim("  #{parsed.inspect[0..600]}")
    exit 1
  end

  parsed
end

# ─── Script entry point ────────────────────────────────────────────────────────

TOTAL_STEPS = 7

puts
puts bold('=' * 66)
puts bold('  SolarPeak · Auth0 Initial Configuration')
puts bold('=' * 66)
puts
puts '  This script configures Auth0 and generates .env files.'
puts yellow('  ⚠  Complete the manual prerequisites at the top of this file')
puts yellow('     before running it.')
puts

puts bold('── Inputs' + ('─' * 57))
puts

domain           = prompt('Auth0 Domain (e.g. dev-abc123.us.auth0.com)')
bootstrap_cid    = prompt('Bootstrap M2M Client ID')
bootstrap_secret = prompt('Bootstrap M2M Client Secret', secret: true)
frontend_url     = prompt('Frontend dev URL',  default: 'http://localhost:3000')
rails_port       = prompt('Rails API port',    default: '3001')
api_identifier   = prompt('API Audience/Identifier', default: 'https://api.solarpeak.dev')

# Normalise domain — strip any accidental https:// prefix or trailing slash
domain = domain.sub(%r{^https?://}, '').chomp('/')
backend_url = "http://localhost:#{rails_port}"

puts
puts bold('── Running' + ('─' * 56))

# ─── Step 1: Obtain Management API token ──────────────────────────────────────

step(1, TOTAL_STEPS, 'Obtaining Management API token')

status, token_body = http_json(
  method: 'POST',
  url:    "https://#{domain}/oauth/token",
  body:   {
    grant_type:    'client_credentials',
    client_id:     bootstrap_cid,
    client_secret: bootstrap_secret,
    audience:      "https://#{domain}/api/v2/"
  }
)

fail!("Token request failed (HTTP #{status}). Check your domain and credentials.\n  #{token_body.inspect}") unless status == 200

mgmt_token = token_body&.fetch('access_token', nil)
fail!('No access_token in response') unless mgmt_token

ok('Management API token obtained')

# ─── Step 2: Create SPA Application (Next.js frontend) ────────────────────────

step(2, TOTAL_STEPS, 'Creating Regular Web Application (Next.js frontend)')

# NOTE: @auth0/nextjs-auth0 handles auth server-side (in Next.js API routes),
# so the app type must be "regular_web" — it needs a client_secret for the
# server-side authorization code exchange. A pure SPA type cannot use a secret.
spa = mgmt(
  method: 'POST', path: '/clients', token: mgmt_token, domain: domain,
  body: {
    name:        'SolarPeak Web',
    app_type:    'regular_web',
    description: 'SolarPeak Next.js frontend — server-side auth via @auth0/nextjs-auth0',
    # Allowed URLs — add production URLs here later
    callbacks:           ["#{frontend_url}/api/auth/callback"],
    allowed_logout_urls: [frontend_url],
    web_origins:         [frontend_url],
    allowed_origins:     [frontend_url],
    grant_types:                ['authorization_code', 'refresh_token'],
    token_endpoint_auth_method: 'client_secret_post',
    oidc_conformant:            true,
    jwt_configuration: {
      alg:                 'RS256',
      lifetime_in_seconds: 36_000  # 10 hours
    },
    refresh_token: {
      rotation_type:                'rotating',
      expiration_type:              'expiring',
      token_lifetime:               2_592_000,    # 30 days absolute
      idle_token_lifetime:          1_296_000,    # 15 days idle
      leeway:                       0,
      infinite_token_lifetime:      false,
      infinite_idle_token_lifetime: false
    }
  }
)

spa_client_id     = spa['client_id']
spa_client_secret = spa['client_secret']
ok("Regular Web App created  ·  Client ID: #{dim(spa_client_id)}")

# ─── Step 3: Create API Resource Server (Rails JWT audience) ──────────────────

step(3, TOTAL_STEPS, 'Creating API resource server (Rails JWT audience)')

mgmt(
  method: 'POST', path: '/resource-servers', token: mgmt_token, domain: domain,
  body: {
    name:                   'SolarPeak API',
    identifier:             api_identifier,
    signing_alg:            'RS256',
    token_lifetime:         86_400,     # 24h
    token_lifetime_for_web: 7_200,      # 2h for browser clients
    skip_consent_for_verifiable_first_party_clients: true,
    enforce_policies: true,
    # Scopes — Rails validates these in JWT claims
    scopes: [
      { value: 'read:solar',    description: 'Query solar trend data' },
      { value: 'manage:users',  description: 'Invite and manage users (admin/manager)' }
    ]
  }
)

ok("API resource server created  ·  Audience: #{dim(api_identifier)}")

# ─── Step 4: Create M2M Application (Rails → Management API) ──────────────────

step(4, TOTAL_STEPS, 'Creating M2M application (Rails backend → Management API)')

m2m = mgmt(
  method: 'POST', path: '/clients', token: mgmt_token, domain: domain,
  body: {
    name:        'SolarPeak Backend (M2M)',
    app_type:    'non_interactive',
    description: 'Rails backend — creates users and dispatches invitation ' \
                 'password-change tickets via Auth0 Management API',
    grant_types:     ['client_credentials'],
    oidc_conformant: true
  }
)

m2m_client_id     = m2m['client_id']
m2m_client_secret = m2m['client_secret']
ok("M2M application created  ·  Client ID: #{dim(m2m_client_id)}")

# ─── Step 5: Grant Management API scopes to the M2M app ───────────────────────

step(5, TOTAL_STEPS, 'Granting Management API scopes to M2M application')

mgmt(
  method: 'POST', path: '/client-grants', token: mgmt_token, domain: domain,
  body: {
    client_id: m2m_client_id,
    audience:  "https://#{domain}/api/v2/",
    scope: %w[
      create:users
      read:users
      update:users
      delete:users
      create:user_tickets
      read:user_tickets
      read:connections
    ]
    # Scope notes:
    #   create:users        — provision new user accounts during invitation
    #   read:users          — look up users by email / sub
    #   update:users        — deactivate / block users
    #   delete:users        — hard-delete users (admin only, enforced in Rails)
    #   create:user_tickets — generate password-change/setup email tickets
    #   read:user_tickets   — verify ticket status
    #   read:connections    — enumerate database connections (used during invite)
  }
)

ok('Scopes granted: create/read/update/delete :users + :user_tickets + read:connections')

# ─── Step 6: Verify Username-Password-Authentication connection ────────────────

step(6, TOTAL_STEPS, "Verifying 'Username-Password-Authentication' connection")

connections = mgmt(
  method: 'GET',
  path:   '/connections?strategy=auth0&fields=id,name&include_fields=true',
  token:  mgmt_token,
  domain: domain
)

db_conn = Array(connections).find { |c| c['name'] == 'Username-Password-Authentication' }

if db_conn
  ok("Connection verified  ·  ID: #{dim(db_conn['id'])}")
else
  warn_msg("Could not confirm 'Username-Password-Authentication' connection.")
  warn_msg('Verify it is enabled: Auth0 Dashboard → Authentication → Database.')
end

# ─── Step 7: Write environment files ──────────────────────────────────────────

step(7, TOTAL_STEPS, 'Writing .env files')

auth0_secret = SecureRandom.hex(32)   # Used by @auth0/nextjs-auth0 to encrypt cookies

backend_env_content = <<~ENV
  # ─────────────────────────────────────────────────────────────────────────────
  # SolarPeak — Rails Backend Environment Variables
  # Generated by scripts/auth0_setup.rb
  # ⚠  DO NOT COMMIT — add backend/.env to .gitignore
  # ─────────────────────────────────────────────────────────────────────────────

  # ── Auth0: JWT validation ─────────────────────────────────────────────────────
  # Rails middleware decodes every inbound Bearer token against the JWKS endpoint:
  #   https://#{domain}/.well-known/jwks.json
  AUTH0_DOMAIN=#{domain}
  AUTH0_AUDIENCE=#{api_identifier}

  # ── Auth0: Management API (user invitation flow) ──────────────────────────────
  # Rails uses these credentials to obtain a Management API token, then:
  #   1. POST /api/v2/users                  → create invited user
  #   2. POST /api/v2/tickets/password-change → trigger Auth0 invitation email
  AUTH0_MANAGEMENT_CLIENT_ID=#{m2m_client_id}
  AUTH0_MANAGEMENT_CLIENT_SECRET=#{m2m_client_secret}
  AUTH0_MANAGEMENT_AUDIENCE=https://#{domain}/api/v2/

  # ── Database ──────────────────────────────────────────────────────────────────
  DATABASE_URL=postgresql://localhost/solarpeak_development

  # ── Redis (caching layer) ─────────────────────────────────────────────────────
  REDIS_URL=redis://localhost:6379/0

  # ── CORS ──────────────────────────────────────────────────────────────────────
  FRONTEND_URL=#{frontend_url}
ENV

frontend_env_content = <<~ENV
  # ─────────────────────────────────────────────────────────────────────────────
  # SolarPeak — Next.js Frontend Environment Variables
  # Generated by scripts/auth0_setup.rb
  # ⚠  DO NOT COMMIT — add frontend/.env.local to .gitignore
  # ─────────────────────────────────────────────────────────────────────────────

  # ── Auth0 Next.js SDK (@auth0/nextjs-auth0) ───────────────────────────────────
  # AUTH0_SECRET:          Random 32-byte hex string — encrypts the session cookie.
  #                        Rotate this if you suspect it has been compromised.
  # AUTH0_BASE_URL:        The canonical URL of this Next.js app.
  # AUTH0_ISSUER_BASE_URL: Your Auth0 tenant URL.
  # AUTH0_CLIENT_ID:       Regular Web App Client ID.
  # AUTH0_CLIENT_SECRET:   Required — @auth0/nextjs-auth0 exchanges the auth code
  #                        server-side and needs the secret to do so.
  # AUTH0_AUDIENCE:        Must match the Rails API resource server identifier so
  #                        the issued JWT is accepted by the backend.
  AUTH0_SECRET=#{auth0_secret}
  AUTH0_BASE_URL=#{frontend_url}
  AUTH0_ISSUER_BASE_URL=https://#{domain}
  AUTH0_CLIENT_ID=#{spa_client_id}
  AUTH0_CLIENT_SECRET=#{spa_client_secret}
  AUTH0_AUDIENCE=#{api_identifier}
  AUTH0_SCOPE=openid profile email

  # ── Rails API ─────────────────────────────────────────────────────────────────
  # NEXT_PUBLIC_ prefix makes this available in the browser bundle.
  NEXT_PUBLIC_API_URL=#{backend_url}
ENV

# Blank out values for the .example files — comments and blank lines are preserved
def to_example(env_string)
  env_string.gsub(/^([A-Z][A-Z0-9_]+=).+$/, '\1')
end

FileUtils.mkdir_p('backend')
FileUtils.mkdir_p('frontend')

File.write('backend/.env',          backend_env_content)
File.write('frontend/.env.local',   frontend_env_content)
File.write('backend/.env.example',  to_example(backend_env_content))
File.write('frontend/.env.example', to_example(frontend_env_content))

ok("backend/.env             written  #{dim('← gitignore this')}")
ok("frontend/.env.local      written  #{dim('← gitignore this')}")
ok("backend/.env.example     written  #{dim('← safe to commit')}")
ok("frontend/.env.example    written  #{dim('← safe to commit')}")

# ─── Summary ──────────────────────────────────────────────────────────────────

puts
puts bold('=' * 66)
puts bold("  #{green('✓')} Auth0 setup complete!")
puts bold('=' * 66)
puts
puts "  Resources created in tenant #{bold(domain)}:"
puts "    #{green('•')} Regular Web App      SolarPeak Web         #{dim(spa_client_id)}"
puts "    #{green('•')} API Resource Server  SolarPeak API         #{dim(api_identifier)}"
puts "    #{green('•')} M2M Application      SolarPeak Backend     #{dim(m2m_client_id)}"
puts
puts bold('  Next steps:')
puts "    1. Add #{yellow('backend/.env')} and #{yellow('frontend/.env.local')} to #{yellow('.gitignore')}"
puts '    2. Commit the .env.example files so teammates know what vars are needed'
puts "    3. #{yellow('Delete')} the 'SolarPeak Bootstrap' M2M app from the Auth0 Dashboard"
puts '       once this setup is verified — it holds broad Management API permissions'
puts '    4. For production: configure a custom email provider so Auth0 can send'
puts '       invitation emails via your own domain:'
puts dim('       Auth0 Dashboard → Branding → Email Provider (SendGrid, Mailgun, …)')
puts '    5. Optionally customise the login page:'
puts dim('       Auth0 Dashboard → Branding → Universal Login')
puts
puts dim("  Auth0 Dashboard: https://manage.auth0.com/dashboard/us/#{domain.split('.').first}")
puts bold('=' * 66)
puts
