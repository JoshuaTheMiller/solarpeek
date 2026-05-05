# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require_relative '../config/environment'
require 'rspec/rails'
require 'shoulda/matchers'
require 'webmock/rspec'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Stub all external HTTP requests in tests (prevents accidental Auth0/API calls)
  WebMock.disable_net_connect!(allow_localhost: true)
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library        :rails
  end
end

# ── Auth helpers ────────────────────────────────────────────────────────────
module AuthHelpers
  # Stubs JWT verification and returns the given user from the DB lookup.
  # Call this in request specs that need an authenticated user.
  def sign_in(user)
    allow(JsonWebToken).to receive(:verify).and_return(
      [{ 'sub' => user.auth0_sub, 'email' => user.email }, {}]
    )
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
