# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'

# Load .env files before anything else
require 'dotenv/rails-now'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SolarpeakApi
  class Application < Rails::Application
    config.load_defaults 7.1

    # API-only mode — no views, sessions, cookies, or browser middleware
    config.api_only = true

    # Default timezone
    config.time_zone = 'UTC'

    # Eager load all app/ files in production for performance
    config.eager_load_paths << Rails.root.join('app/services')
    config.eager_load_paths << Rails.root.join('app/policies')

    # Return JSON errors for unhandled exceptions
    config.exceptions_app = routes
  end
end
