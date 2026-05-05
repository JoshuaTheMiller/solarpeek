# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Rswag writes the generated spec here; Rswag::Api serves it from this path.
  # File is created at: public/openapi/v1/swagger.json
  # Served at:          GET /openapi/v1/swagger.json
  config.openapi_root = Rails.root.join('public/openapi').to_s

  config.openapi_specs = {
    'v1/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title:       'SolarPeak API',
        description: 'Historical solar generation data API. ' \
                     'All endpoints require a valid Auth0 Bearer token.',
        version:     'v1'
      },
      servers: [
        { url: 'http://localhost:3001', description: 'Local development' },
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type:         'http',
            scheme:       'bearer',
            bearerFormat: 'JWT',
            description:  'Auth0 JWT access token. ' \
                          'Obtain via Auth0 login; pass as "Authorization: Bearer <token>".'
          }
        },
        schemas: {
          # ── Shared schemas ────────────────────────────────────────────────
          Error: {
            type: 'object',
            properties: {
              error: { type: 'string', description: 'Human-readable error message' }
            },
            required: ['error']
          },
          User: {
            type: 'object',
            properties: {
              id:               { type: 'integer' },
              email:            { type: 'string', format: 'email' },
              role:             { type: 'string', enum: %w[viewer manager admin] },
              query_limit_days: { type: 'integer', description: 'Max date-range span in days' },
              active:           { type: 'boolean' },
              invited_by_id:    { type: 'integer', nullable: true },
              created_at:       { type: 'string', format: 'date-time' }
            },
            required: %w[id email role query_limit_days active created_at]
          },
          SolarReading: {
            type: 'object',
            properties: {
              timestamp: { type: 'string', format: 'date-time' },
              wattage:   { type: 'number', format: 'float', description: 'Watts at this timestamp' }
            },
            required: %w[timestamp wattage]
          }
        }
      },
      security: [{ bearerAuth: [] }]
    }
  }

  # Format all generated request bodies as JSON
  config.openapi_format = :json
end
