# frozen_string_literal: true

# PHASE 1: Core Domain - Observation
#
# An Observation represents what the agent learned from a diagnostic action.
# After calling a tool (logs, metrics, etc.), the agent records what it saw.
#
# GUIDELINES:
# - Observations are immutable value objects
# - They link to a specific tool invocation
# - The `summary` is a human-readable description of findings
# - The `raw_data` contains the actual tool output for reference
# - `significant` flag indicates if this changed the agent's understanding
#
# HINTS:
# - Think about what makes an observation useful for debugging
# - The agent uses observations to build its mental model of the incident

require "spec_helper"

RSpec.describe OncallGym::Incidents::Observation do
  describe ".new" do
    it "creates an observation with required fields" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found repeated connection timeout errors to database"
      )

      expect(observation.tool_name).to eq("logs")
      expect(observation.summary).to eq("Found repeated connection timeout errors to database")
    end

    it "auto-generates an ID" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found errors"
      )

      expect(observation.id).not_to be_nil
      expect(observation.id).to be_a(String)
    end

    it "stores raw_data from tool output" do
      raw = { entries: [{ message: "timeout", level: "error" }] }
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found timeout errors",
        raw_data: raw
      )

      expect(observation.raw_data).to eq(raw)
    end

    it "defaults raw_data to nil" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found errors"
      )

      expect(observation.raw_data).to be_nil
    end

    it "tracks whether the observation is significant" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found critical error pattern",
        significant: true
      )

      expect(observation.significant).to be true
    end

    it "defaults significant to false" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Logs look normal"
      )

      expect(observation.significant).to be false
    end

    it "records the timestamp" do
      before = Time.now
      observation = described_class.new(
        tool_name: "metrics",
        summary: "CPU spike at 14:32"
      )
      after = Time.now

      expect(observation.recorded_at).to be >= before
      expect(observation.recorded_at).to be <= after
    end

    it "accepts tool_params to record what was queried" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found errors in checkout service",
        tool_params: { service: "checkout", level: "error", limit: 100 }
      )

      expect(observation.tool_params[:service]).to eq("checkout")
      expect(observation.tool_params[:level]).to eq("error")
    end
  end

  describe "#to_h" do
    it "serializes the observation" do
      observation = described_class.new(
        tool_name: "logs",
        summary: "Found errors",
        significant: true,
        tool_params: { service: "checkout" }
      )

      hash = observation.to_h

      expect(hash[:tool_name]).to eq("logs")
      expect(hash[:summary]).to eq("Found errors")
      expect(hash[:significant]).to be true
      expect(hash[:tool_params]).to eq({ service: "checkout" })
    end
  end

  describe "#significant?" do
    it "returns the significant flag" do
      significant = described_class.new(tool_name: "logs", summary: "x", significant: true)
      normal = described_class.new(tool_name: "logs", summary: "y", significant: false)

      expect(significant.significant?).to be true
      expect(normal.significant?).to be false
    end
  end
end
