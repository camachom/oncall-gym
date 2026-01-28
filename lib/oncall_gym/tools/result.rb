# frozen_string_literal: true

module OncallGym
  module Tools
    class Result
      attr_reader :success, :tool_name, :errors, :data, :execution_time_ms

      def initialize(query: nil, tool_name: nil, errors: [], limit: nil, execution_time_ms: nil, data: nil, success: nil)
        @query = query
        @success = success
        @tool_name = tool_name
        @errors = errors
        @limit = limit
        @execution_time_ms = execution_time_ms
        @data = data
      end

      def self.failure(tool_name:, errors:)
        Result.new(
          tool_name: tool_name,
          errors: errors,
          success: false
        )
      end

      def self.success(tool_name:, data:, execution_time_ms:)
        Result.new(
          tool_name: tool_name,
          data: data,
          execution_time_ms: execution_time_ms,
          success: true
        )
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      def to_h
        {
          query: @query,
          success: @success,
          tool_name: @tool_name,
          errors: @errors,
          limit: @limit,
          execution_time_ms: @execution_time_ms,
          data: @data
        }
      end
    end
  end
end
