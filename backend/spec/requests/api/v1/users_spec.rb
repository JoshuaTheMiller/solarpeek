# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  let(:admin)   { create(:user, :admin)   }
  let(:manager) { create(:user, :manager) }
  let(:viewer)  { create(:user, :viewer)  }
  let(:target)  { create(:user, :viewer)  }

  path '/api/v1/users' do
    get 'List all users (admin + manager only)' do
      tags     'Users'
      security [{ bearerAuth: [] }]
      produces 'application/json'

      response '200', 'Users returned' do
        schema type: :object,
          properties: {
            data: { type: :array, items: { '$ref' => '#/components/schemas/User' } }
          }

        before { sign_in(admin) }
        let(:Authorization) { 'Bearer valid_token' }
        run_test!
      end

      response '403', 'Viewer cannot list users' do
        schema '$ref' => '#/components/schemas/Error'
        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/query_limit' do
    parameter name: :id, in: :path, type: :integer, required: true

    patch 'Update a user query limit (admin + manager only)' do
      tags     'Users'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name:     :body,
                in:       :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    query_limit_days: { type: :integer, minimum: 1 }
                  },
                  required: ['query_limit_days']
                }

      response '200', 'Query limit updated' do
        schema type: :object,
          properties: { data: { '$ref' => '#/components/schemas/User' } }

        before { sign_in(admin) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:id)   { target.id }
        let(:body) { { query_limit_days: 60 } }
        run_test!
      end

      response '403', 'Viewer cannot set query limits' do
        schema '$ref' => '#/components/schemas/Error'
        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:id)   { target.id }
        let(:body) { { query_limit_days: 60 } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true

    delete 'Deactivate a user (admin + manager only)' do
      tags     'Users'
      security [{ bearerAuth: [] }]
      produces 'application/json'
      description 'Soft-deactivates the user in the local DB and blocks them in Auth0.'

      response '200', 'User deactivated' do
        schema type: :object,
          properties: { data: { '$ref' => '#/components/schemas/User' } }

        before do
          sign_in(manager)
          allow(Auth0ManagementService).to receive(:deactivate_user)
        end
        let(:Authorization) { 'Bearer valid_token' }
        let(:id)            { target.id }
        run_test!
      end

      response '403', 'Cannot deactivate an admin' do
        schema '$ref' => '#/components/schemas/Error'
        before { sign_in(manager) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:id)            { admin.id }
        run_test!
      end
    end
  end
end
