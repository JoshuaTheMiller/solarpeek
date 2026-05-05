# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'GET /api/v1/solar/readings', type: :request do
  let(:viewer)  { create(:user, :viewer,  query_limit_days: 30)  }
  let(:admin)   { create(:user, :admin,   query_limit_days: 365) }

  path '/api/v1/solar/readings' do
    get 'Fetch historical solar readings for a date range' do
      tags        'Solar'
      security    [{ bearerAuth: [] }]
      produces    'application/json'
      description <<~DESC
        Returns hourly wattage readings for the requested date range.

        The range is validated against the calling user's `query_limit_days`.
        If the requested range exceeds the limit, a 422 is returned with a
        message explaining the limit.

        The response `meta` object always includes `query_limit_days` so the
        frontend can re-render the limit banner without an extra `/me` call.
      DESC

      parameter name:        :start_date,
                in:          :query,
                type:        :string,
                required:    true,
                description: 'Start of the date range (YYYY-MM-DD)'

      parameter name:        :end_date,
                in:          :query,
                type:        :string,
                required:    true,
                description: 'End of the date range, inclusive (YYYY-MM-DD)'

      # ── 200 ───────────────────────────────────────────────────────────────
      response '200', 'Solar readings returned' do
        schema type: :object,
          properties: {
            data: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            meta: {
              type: :object,
              properties: {
                query_limit_days: { type: :integer },
                requested_days:   { type: :integer }
              },
              required: %w[query_limit_days requested_days]
            }
          },
          required: %w[data meta]

        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:start_date)    { '2024-01-01' }
        let(:end_date)      { '2024-01-07' }
        run_test!
      end

      # ── 422 — range exceeds limit ─────────────────────────────────────────
      response '422', 'Date range exceeds the user query limit' do
        schema '$ref' => '#/components/schemas/Error'

        before { sign_in(viewer) }   # viewer has 30-day limit
        let(:Authorization) { 'Bearer valid_token' }
        let(:start_date)    { '2024-01-01' }
        let(:end_date)      { '2024-04-01' }  # 91 days — exceeds 30-day limit
        run_test!
      end

      # ── 422 — invalid dates ───────────────────────────────────────────────
      response '422', 'Invalid date format' do
        schema '$ref' => '#/components/schemas/Error'

        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:start_date)    { 'not-a-date' }
        let(:end_date)      { '2024-01-07' }
        run_test!
      end

      # ── 401 ───────────────────────────────────────────────────────────────
      response '401', 'Unauthenticated' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { nil }
        let(:start_date)    { '2024-01-01' }
        let(:end_date)      { '2024-01-07' }
        run_test!
      end
    end
  end
end
