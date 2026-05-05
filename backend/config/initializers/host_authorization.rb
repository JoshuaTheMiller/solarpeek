# frozen_string_literal: true

# In docker-compose, requests can arrive with Host: backend:3001
# from the frontend container's proxy route.
if Rails.env.development?
  Rails.application.config.hosts << 'backend'
end
