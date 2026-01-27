# frozen_string_literal: true

require "securerandom"

module OncallGym
  module Incidents
    class Hypothesis
      attr_reader :id, :description, :confidence, :status,
                  :supporting_observation_ids, :proposed_mitigation

      VALID_STATUSES = %i[investigating supported refuted actionable].freeze

      def initialize(
        description:,
        id: nil,
        confidence: 0.0,
        status: :investigating,
        supporting_observation_ids: [],
        proposed_mitigation: nil
      )
        validate_confidence!(confidence)
        validate_status!(status)

        @id = id || SecureRandom.uuid
        @description = description
        @confidence = confidence
        @status = status
        @supporting_observation_ids = supporting_observation_ids.dup.freeze
        @proposed_mitigation = proposed_mitigation
      end

      def with_confidence(new_confidence)
        self.class.new(
          id: id,
          description: description,
          confidence: new_confidence,
          status: status,
          supporting_observation_ids: supporting_observation_ids,
          proposed_mitigation: proposed_mitigation,
        )
      end

      def with_status(new_status)
        self.class.new(
          id: id,
          description: description,
          confidence: confidence,
          status: new_status,
          supporting_observation_ids: supporting_observation_ids,
          proposed_mitigation: proposed_mitigation,
        )
      end

      def with_observation(observation_id)
        self.class.new(
          id: id,
          description: description,
          confidence: confidence,
          status: status,
          supporting_observation_ids: supporting_observation_ids + [observation_id],
          proposed_mitigation: proposed_mitigation,
        )
      end

      def with_mitigation(mitigation)
        self.class.new(
          id: id,
          description: description,
          confidence: confidence,
          status: status,
          supporting_observation_ids: supporting_observation_ids,
          proposed_mitigation: mitigation,
        )
      end

      def actionable?
        status == :actionable
      end

      def high_confidence?
        confidence >= 0.8
      end

      def to_h
        {
          id: id,
          description: description,
          confidence: confidence,
          status: status,
          supporting_observation_ids: supporting_observation_ids,
          proposed_mitigation: proposed_mitigation,
        }
      end

      private

      def validate_confidence!(value)
        return if value >= 0.0 && value <= 1.0

        raise ValidationError, "confidence must be between 0.0 and 1.0"
      end

      def validate_status!(value)
        return if VALID_STATUSES.include?(value)

        raise ValidationError, "invalid status: #{value}"
      end
    end
  end
end
