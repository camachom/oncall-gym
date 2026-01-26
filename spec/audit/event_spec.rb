# frozen_string_literal: true

# PHASE 5: Audit Trail - Event
#
# An Event represents a single auditable action in the system.
# Events form the complete record of agent behavior.
#
# GUIDELINES:
# - Events are immutable and timestamped
# - Event types: run_started, step_started, tool_called, observation_recorded,
#                hypothesis_updated, step_completed, run_completed, etc.
# - Events include all relevant context for replay/debugging
# - Events can be serialized for storage
#
# HINTS:
# - Think about what you'd need to reconstruct agent behavior later
# - Events should be self-contained (no external references needed)
# - Consider event sourcing patterns

require "spec_helper"

RSpec.describe OncallGym::Audit::Event do
  describe ".new" do
    it "creates an event with required fields" do
      event = described_class.new(
        type: :tool_called,
        run_id: "run-123",
        data: { tool_name: "logs", params: { service: "checkout" } }
      )

      expect(event.type).to eq(:tool_called)
      expect(event.run_id).to eq("run-123")
      expect(event.data[:tool_name]).to eq("logs")
    end

    it "auto-generates an ID" do
      event = described_class.new(type: :run_started, run_id: "run-123", data: {})

      expect(event.id).not_to be_nil
    end

    it "records timestamp automatically" do
      before = Time.now
      event = described_class.new(type: :run_started, run_id: "run-123", data: {})
      after = Time.now

      expect(event.timestamp).to be >= before
      expect(event.timestamp).to be <= after
    end

    it "accepts explicit timestamp" do
      specific_time = Time.new(2024, 1, 15, 10, 30, 0)
      event = described_class.new(
        type: :run_started,
        run_id: "run-123",
        data: {},
        timestamp: specific_time
      )

      expect(event.timestamp).to eq(specific_time)
    end

    it "validates event type is known" do
      expect {
        described_class.new(type: :unknown_type, run_id: "run-123", data: {})
      }.to raise_error(OncallGym::ValidationError, /type/)
    end

    it "accepts optional step_id for step-level events" do
      event = described_class.new(
        type: :tool_called,
        run_id: "run-123",
        step_id: "step-456",
        data: { tool_name: "logs" }
      )

      expect(event.step_id).to eq("step-456")
    end
  end

  describe "event types" do
    it "supports run lifecycle events" do
      [:run_started, :run_completed, :run_failed, :run_escalated].each do |type|
        event = described_class.new(type: type, run_id: "run-123", data: {})
        expect(event.type).to eq(type)
      end
    end

    it "supports step lifecycle events" do
      [:step_started, :step_completed, :step_failed].each do |type|
        event = described_class.new(type: type, run_id: "run-123", step_id: "step-1", data: {})
        expect(event.type).to eq(type)
      end
    end

    it "supports agent action events" do
      [:decision_made, :tool_called, :tool_result_received].each do |type|
        event = described_class.new(type: type, run_id: "run-123", step_id: "step-1", data: {})
        expect(event.type).to eq(type)
      end
    end

    it "supports observation and hypothesis events" do
      [:observation_recorded, :hypothesis_created, :hypothesis_updated].each do |type|
        event = described_class.new(type: type, run_id: "run-123", data: {})
        expect(event.type).to eq(type)
      end
    end
  end

  describe "#to_h" do
    it "serializes the event" do
      event = described_class.new(
        type: :tool_called,
        run_id: "run-123",
        step_id: "step-1",
        data: { tool_name: "logs", params: { service: "checkout" } }
      )

      hash = event.to_h

      expect(hash[:id]).not_to be_nil
      expect(hash[:type]).to eq(:tool_called)
      expect(hash[:run_id]).to eq("run-123")
      expect(hash[:step_id]).to eq("step-1")
      expect(hash[:data]).to eq({ tool_name: "logs", params: { service: "checkout" } })
      expect(hash[:timestamp]).to be_a(Time)
    end
  end

  describe "#to_json" do
    it "serializes to JSON" do
      event = described_class.new(
        type: :tool_called,
        run_id: "run-123",
        data: { tool_name: "logs" }
      )

      json = event.to_json

      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed["type"]).to eq("tool_called")
    end
  end

  describe ".from_json" do
    it "deserializes from JSON" do
      original = described_class.new(
        type: :tool_called,
        run_id: "run-123",
        data: { tool_name: "logs" }
      )

      restored = described_class.from_json(original.to_json)

      expect(restored.type).to eq(:tool_called)
      expect(restored.run_id).to eq("run-123")
      expect(restored.id).to eq(original.id)
    end
  end

  describe "convenience constructors" do
    describe ".run_started" do
      it "creates a run_started event" do
        event = described_class.run_started(
          run_id: "run-123",
          incident_id: "inc-456",
          incident_description: "latency spike"
        )

        expect(event.type).to eq(:run_started)
        expect(event.data[:incident_id]).to eq("inc-456")
      end
    end

    describe ".tool_called" do
      it "creates a tool_called event" do
        event = described_class.tool_called(
          run_id: "run-123",
          step_id: "step-1",
          tool_name: "logs",
          params: { service: "checkout" }
        )

        expect(event.type).to eq(:tool_called)
        expect(event.data[:tool_name]).to eq("logs")
        expect(event.data[:params]).to eq({ service: "checkout" })
      end
    end

    describe ".observation_recorded" do
      it "creates an observation_recorded event" do
        event = described_class.observation_recorded(
          run_id: "run-123",
          step_id: "step-1",
          observation_id: "obs-789",
          summary: "Found timeout errors",
          significant: true
        )

        expect(event.type).to eq(:observation_recorded)
        expect(event.data[:summary]).to eq("Found timeout errors")
        expect(event.data[:significant]).to be true
      end
    end
  end
end
