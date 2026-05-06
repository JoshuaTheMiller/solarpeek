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
                required:    false,
                description: 'Start of the date range (YYYY-MM-DD). Defaults to today minus 364 days.'

      parameter name:        :end_date,
                in:          :query,
                type:        :string,
                required:    false,
                description: 'End of the date range, inclusive (YYYY-MM-DD). Defaults to today.'

      parameter name:        :return_best_day,
            in:          :query,
            type:        :boolean,
            required:    false,
            description: 'When true, include best_readings in the response (default: false)'

      parameter name:        :return_worst_day,
            in:          :query,
            type:        :boolean,
            required:    false,
            description: 'When true, include worst_readings in the response (default: false)'

      parameter name:        :return_today,
            in:          :query,
            type:        :boolean,
            required:    false,
            description: 'When true, include today_readings in the response (default: false)'

      parameter name:        :timezone,
            in:          :query,
            type:        :string,
            required:    false,
            description: 'Optional IANA timezone (for example, America/Los_Angeles) used to compute "today" and default date range.'

      # ── 200 ───────────────────────────────────────────────────────────────
      response '200', 'Solar readings returned' do
        schema type: :object,
          properties: {
            data: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_date: {
              type: :string,
              nullable: true
            },
            worst_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            worst_date: {
              type: :string,
              nullable: true
            },
            today_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            today_date: {
              type: :string
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
          required: %w[data best_readings best_date worst_readings worst_date today_readings today_date meta]

        before do
          sign_in(viewer)
          allow(SolarDataService).to receive(:fetch).and_return(
            {
              readings: [{ timestamp: '2024-01-01T09:00:00Z', wattage: 500.0 }],
              best_readings: [],
              best_date: nil,
              worst_readings: [],
              worst_date: nil,
              today_readings: [],
              today_date: Date.current.iso8601
            }
          )
        end

        let(:Authorization) { 'Bearer valid_token' }
        let(:start_date)    { '2024-01-01' }
        let(:end_date)      { '2024-01-07' }

        run_test! do |response|
          payload = JSON.parse(response.body)

          expect(payload['data']).to be_a(Array)
          expect(payload['meta']).to include('query_limit_days', 'requested_days')
          expect(payload['best_readings']).to eq([])
          expect(payload['best_date']).to be_nil
          expect(payload['worst_readings']).to eq([])
          expect(payload['worst_date']).to be_nil
          expect(payload['today_readings']).to eq([])
          expect(payload['today_date']).to eq(Date.current.iso8601)
        end
      end

      response '200', 'Solar readings returned with optional overlays' do
        schema type: :object,
          properties: {
            data: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_date: {
              type: :string,
              nullable: true
            },
            worst_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            worst_date: {
              type: :string,
              nullable: true
            },
            today_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            today_date: {
              type: :string
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
          required: %w[data best_readings best_date worst_readings worst_date today_readings today_date meta]

        before do
          sign_in(viewer)
          allow(SolarDataService).to receive(:fetch).and_return(
            {
              readings: [
                { timestamp: '2024-01-01T01:00:00Z', wattage: 100.0 }
              ],
              best_readings: [
                { timestamp: '2024-01-03T01:00:00Z', wattage: 220.0 }
              ],
              best_date: '2024-01-03',
              worst_readings: [
                { timestamp: '2024-01-02T01:00:00Z', wattage: 20.0 }
              ],
              worst_date: '2024-01-02',
              today_readings: [
                { timestamp: '2024-01-01T01:00:00Z', wattage: 100.0 }
              ],
              today_date: Date.current.iso8601
            }
          )
        end

        let(:Authorization)     { 'Bearer valid_token' }
        let(:start_date)        { '2024-01-01' }
        let(:end_date)          { '2024-01-07' }
        let(:return_best_day)   { true }
        let(:return_worst_day)  { true }
        let(:return_today)      { true }

        run_test! do |response|
          payload = JSON.parse(response.body)

          expect(payload['data']).to be_an(Array)
          expect(payload['best_readings']).to be_an(Array)
          expect(payload['worst_readings']).to be_an(Array)
          expect(payload['today_readings']).to be_an(Array)

          expect(payload['best_readings'].first).to include('timestamp', 'wattage')
          expect(payload['best_date']).to eq('2024-01-03')
          expect(payload['worst_readings'].first).to include('timestamp', 'wattage')
          expect(payload['worst_date']).to eq('2024-01-02')
          expect(payload['today_readings'].first).to include('timestamp', 'wattage')
          expect(payload['today_date']).to eq(Date.current.iso8601)
        end
      end

      response '200', 'Solar readings returned with timezone-aware today selection' do
        schema type: :object,
          properties: {
            data: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            best_date: {
              type: :string,
              nullable: true
            },
            worst_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            worst_date: {
              type: :string,
              nullable: true
            },
            today_readings: {
              type:  :array,
              items: { '$ref' => '#/components/schemas/SolarReading' }
            },
            today_date: {
              type: :string
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
          required: %w[data best_readings best_date worst_readings worst_date today_readings today_date meta]

        before do
          sign_in(viewer)
          allow(Time).to receive(:current).and_return(Time.utc(2026, 5, 6, 12, 0, 0))

          allow(SolarDataService).to receive(:fetch).and_return(
            {
              readings: [],
              best_readings: [],
              best_date: nil,
              worst_readings: [],
              worst_date: nil,
              today_readings: [
                { timestamp: '2026-05-07T01:00:00Z', wattage: 180.0 }
              ],
              today_date: '2026-05-07'
            }
          )
        end

        let(:Authorization) { 'Bearer valid_token' }
        let(:timezone)      { 'Pacific/Kiritimati' }
        let(:return_today)  { true }

        run_test! do |response|
          payload = JSON.parse(response.body)

          expect(SolarDataService).to have_received(:fetch).with(
            hash_including(
              start_date: Date.new(2025, 5, 8),
              end_date: Date.new(2026, 5, 7),
              today_date: Date.new(2026, 5, 7),
              return_today: true
            )
          )
          expect(payload['today_date']).to eq('2026-05-07')
          expect(payload['today_readings']).to be_an(Array)
        end
      end

      # ── 403 — range exceeds limit ─────────────────────────────────────────
      response '403', 'Date range exceeds the user query limit' do
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

      response '422', 'Invalid timezone' do
        schema '$ref' => '#/components/schemas/Error'

        before { sign_in(viewer) }
        let(:Authorization) { 'Bearer valid_token' }
        let(:timezone)      { 'Mars/Olympus_Mons' }

        run_test! do |response|
          payload = JSON.parse(response.body)
          expect(payload.fetch('error')).to include('timezone must be a valid IANA timezone')
        end
      end

      # ── 401 ───────────────────────────────────────────────────────────────
      response '401', 'Unauthenticated' do
        schema '$ref' => '#/components/schemas/Error'

        before do
          # Auth bypass mode (DISABLE_AUTH=true + AM_I_SURE=yes) makes every
          # request authenticate as the bypass user, so a true 401 is not
          # reachable. Skip rather than fail the suite in that environment.
          bypass_active = ENV['DISABLE_AUTH']&.strip&.downcase == 'true' &&
                          ENV['AM_I_SURE']&.strip&.downcase  == 'yes'
          skip 'Auth bypass is active — 401 cannot be exercised in this environment' if bypass_active
        end

        let(:Authorization) { nil }
        let(:start_date)    { '2024-01-01' }
        let(:end_date)      { '2024-01-07' }
        run_test!
      end
    end
  end
end
