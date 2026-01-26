require "securerandom"

module OncallGym
  module Incidents
    class Incident
      attr_reader :service, :description, :severity, :tags, :created_at, :id

      VALID_SEVERITIES = %i[critical high medium low].freeze

      def initialize(service:, description:, severity: :high, id: nil, tags: {})
        validate_severity(severity) if severity != :high

        @id = id || SecureRandom.uuid
        @service = service
        @description = description
        @severity = severity
        @tags = tags.freeze
        @created_at = Time.now
        freeze
      end

      def to_h
        {
          id: @id,
          service: @service,
          description: @description,
          severity: @severity,
          tags: @tags,
          created_at: @created_at,
        }
      end

      private

      def validate_severity(severity)
        return if VALID_SEVERITIES.include? severity

        raise OncallGym::ValidationError, "unknown severity"
      end
    end
  end
end
