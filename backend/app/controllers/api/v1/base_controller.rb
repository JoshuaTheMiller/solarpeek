# frozen_string_literal: true

module Api
  module V1
    # All v1 API controllers inherit from this.
    # Provides versioning namespace and a consistent JSON response helper.
    class BaseController < ApplicationController
      private

      def render_json(data, status: :ok, meta: nil)
        payload = { data: data }
        payload[:meta] = meta if meta
        render json: payload, status: status
      end
    end
  end
end
