# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'GET /api/v1/me', type: :request do
  let(:user) { create(:user, :admin) }

  path '/api/v1/me' do
    get 'Returns the current authenticated user profile' do
      tags        'Identity'
      security    [{ bearerAuth: [] }]
      produces    'application/json'
      description 'Returns id, email, role, and query_limit_days for the ' \
                  'calling user. The frontend uses query_limit_days to ' \
                  'constrain the date-range picker on the solar trends page.'

      response '200', 'Current user returned' do
        schema type: :object,
          properties: {
            data: { '$ref' => '#/components/schemas/User' }
          },
          required: ['data']

        before { sign_in(user) }
        let(:Authorization) { 'Bearer valid_token' }
        run_test!
      end

      response '401', 'No token or invalid token' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { nil }
        run_test!
      end
    end
  end
end
