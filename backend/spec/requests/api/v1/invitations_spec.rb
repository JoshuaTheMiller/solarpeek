# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'POST /api/v1/invitations', type: :request do
  let(:admin)   { create(:user, :admin)   }
  let(:manager) { create(:user, :manager) }
  let(:viewer)  { create(:user, :viewer)  }

  before do
    # Stub Auth0 Management API calls so tests don't make real HTTP requests
    allow(Auth0ManagementService).to receive(:invite_user).and_return('auth0|newuser123')
  end

  path '/api/v1/invitations' do
    post 'Invite a new user (admin + manager only)' do
      tags        'Invitations'
      security    [{ bearerAuth: [] }]
      consumes    'application/json'
      produces    'application/json'
      description <<~DESC
        Creates an Auth0 account for the given email and sends the invitee a
        password-setup email (Auth0 Option A invitation flow).

        The new user is created in the local DB with:
          - The specified role
          - query_limit_days = 30 (default — can be changed after invite)
          - invited_by set to the calling user

        Role restrictions:
          - Admins may invite admins, managers, and viewers
          - Managers may invite managers and viewers only
          - Viewers cannot invite
      DESC

      parameter name:     :body,
                in:       :body,
                required: true,
                schema: {
                  type: :object,
                  properties: {
                    invitation: {
                      type: :object,
                      properties: {
                        email: { type: :string, format: :email },
                        role:  { type: :string, enum: %w[admin manager viewer] }
                      },
                      required: %w[email role]
                    }
                  },
                  required: ['invitation']
                }

      # ── 201 — admin invites a viewer ──────────────────────────────────────
      response '201', 'Invitation sent, user created' do
        schema type: :object,
          properties: { data: { '$ref' => '#/components/schemas/User' } }

        before { sign_in(admin) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:body) { { invitation: { email: 'newviewer@solarpeak.test', role: 'viewer' } } }
        run_test!
      end

      # ── 403 — manager tries to invite admin ───────────────────────────────
      response '403', 'Manager cannot invite admin' do
        schema '$ref' => '#/components/schemas/Error'

        before { sign_in(manager) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:body) { { invitation: { email: 'newadmin@solarpeak.test', role: 'admin' } } }
        run_test!
      end

      # ── 403 — viewer cannot invite anyone ────────────────────────────────
      response '403', 'Viewer cannot invite' do
        schema '$ref' => '#/components/schemas/Error'

        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:body) { { invitation: { email: 'someone@solarpeak.test', role: 'viewer' } } }
        run_test!
      end

      # ── 422 — email already exists ────────────────────────────────────────
      response '422', 'Email already registered' do
        schema '$ref' => '#/components/schemas/Error'

        before do
          sign_in(admin)
          create(:user, email: 'existing@solarpeak.test')
        end
        let(:Authorization) { 'Bearer valid_token' }
        let(:body) { { invitation: { email: 'existing@solarpeak.test', role: 'viewer' } } }
        run_test!
      end
    end
  end
end
