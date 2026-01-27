require "securerandom"

module OncallGym
  module Incidents
    class Observation
        attr_reader :tool_name, :summary, :raw_data, :id, :significant, :recorded_at, :tool_params

        def initialize(tool_name:, summary:, significant: false, raw_data: nil, tool_params: nil)
            @id = SecureRandom.uuid
            @tool_name = tool_name
            @summary = summary
            @raw_data = raw_data
            @significant = significant
            @recorded_at = Time.now
            @tool_params = tool_params

            freeze
        end

        def to_h
            {
                id: @id,
                tool_name: @tool_name,
                summary: @summary,
                raw_data: @raw_data,
                significant: @significant,
                recorded_at: @recorded_at,
                tool_params: @tool_params
            }
        end

        def significant?
            @significant
        end
    end
  end
end