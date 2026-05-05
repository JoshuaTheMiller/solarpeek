# frozen_string_literal: true

# Rswag::Api serves the generated OpenAPI spec files from openapi_root.
# The spec is mounted at /openapi (see config/routes.rb), so the full URL is:
#   GET /openapi/v1/swagger.json
#
# The human-readable docs are served as a static file by Rails at:
#   GET /api-docs  →  public/api-docs/index.html  (Redocly embed)
#
# To regenerate the spec after changing request specs:
#   bundle exec rails rswag:specs:swaggerize

Rswag::Api.configure do |c|
  c.openapi_root = Rails.root.join('public/openapi').to_s
end
