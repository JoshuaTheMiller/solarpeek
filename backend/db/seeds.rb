# frozen_string_literal: true

# =============================================================================
# SolarPeak — Database Seeds
# =============================================================================
#
# Creates the initial admin user. Must be run after the Auth0 user already
# exists (either created manually in the Auth0 Dashboard or via the API).
#
# Required env vars (set in backend/.env):
#   ADMIN_AUTH0_SUB   — the Auth0 "sub" of the admin user (e.g. auth0|abc123)
#   ADMIN_EMAIL       — the admin's email address
#
# Usage:
#   bundle exec rails db:seed
# =============================================================================

admin_sub   = ENV['ADMIN_AUTH0_SUB'].presence
admin_email = ENV['ADMIN_EMAIL'].presence

if admin_sub.nil? || admin_email.nil?
  puts "⚠  Skipping admin seed — ADMIN_AUTH0_SUB and ADMIN_EMAIL are not set."
  puts "   Add them to backend/.env and re-run: bundle exec rails db:seed"
else
  user = User.find_or_initialize_by(auth0_sub: admin_sub)

  if user.new_record?
    user.assign_attributes(
      email:            admin_email,
      role:             'admin',
      query_limit_days: 365,   # generous limit for the admin
      active:           true
    )
    user.save!
    puts "✓ Admin user created: #{admin_email} (sub: #{admin_sub})"
  else
    puts "✓ Admin user already exists: #{user.email}"
  end
end
