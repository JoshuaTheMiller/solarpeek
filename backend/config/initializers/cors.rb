# frozen_string_literal: true

# Allow requests from the Next.js frontend.
# FRONTEND_URL is set in backend/.env (e.g. http://localhost:3000).
# Add production URLs to the origins array when deploying.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

    resource '*',
      headers:     :any,
      methods:     %i[get post put patch delete options head],
      credentials: false,
      max_age:     600
  end
end
