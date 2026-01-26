# frozen_string_literal: true

# PHASE 3: Workflow Engine - Step
#
# A Step represents a single iteration of the agent's decision loop.
# Each step captures: what the agent decided, what tool it used, what it learned.
#
# GUIDELINES:
# - Steps are immutable records of agent actions
# - Each step has: decision, tool_call, observation, updated_hypothesis
# - Steps track timing and sequence (step number)
# - Status: pending, executing, completed, failed
#
# HINTS:
# - Think about what you'd want to see when debugging agent behavior
# - Steps are the "unit of work" in the audit trail
# - Consider what happens when a step fails mid-execution

require "spec_helper"

RSpec.describe OncallGym::Workflows::Step do
  describe ".new" do
    it "creates a step with required fields" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs for error patterns"
      )

      expect(step.run_id).to eq("run-123")
      expect(step.step_number).to eq(1)
      expect(step.decision).to eq("Check logs for error patterns")
    end

    it "auto-generates an ID" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs"
      )

      expect(step.id).not_to be_nil
    end

    it "defaults status to :pending" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs"
      )

      expect(step.status).to eq(:pending)
    end

    it "accepts valid status values" do
      [:pending, :executing, :completed, :failed].each do |status|
        step = described_class.new(
          run_id: "run-123",
          step_number: 1,
          decision: "Check logs",
          status: status
        )
        expect(step.status).to eq(status)
      end
    end

    it "records created_at timestamp" do
      before = Time.now
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs"
      )
      after = Time.now

      expect(step.created_at).to be >= before
      expect(step.created_at).to be <= after
    end

    it "accepts tool_call information" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs for errors",
        tool_call: {
          tool_name: "logs",
          params: { service: "checkout", level: "error" }
        }
      )

      expect(step.tool_call[:tool_name]).to eq("logs")
      expect(step.tool_call[:params][:service]).to eq("checkout")
    end

    it "accepts observation (what the agent learned)" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        observation: "Found repeated timeout errors to payment service"
      )

      expect(step.observation).to eq("Found repeated timeout errors to payment service")
    end

    it "accepts hypothesis state changes" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        hypothesis_before: { id: "h1", confidence: 0.3 },
        hypothesis_after: { id: "h1", confidence: 0.6 }
      )

      expect(step.hypothesis_before[:confidence]).to eq(0.3)
      expect(step.hypothesis_after[:confidence]).to eq(0.6)
    end
  end

  describe "#with_status" do
    it "returns new step with updated status" do
      original = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        status: :pending
      )

      updated = original.with_status(:executing)

      expect(updated.status).to eq(:executing)
      expect(original.status).to eq(:pending)
      expect(updated.id).to eq(original.id)
    end
  end

  describe "#with_tool_result" do
    it "returns new step with tool result attached" do
      original = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        tool_call: { tool_name: "logs", params: { service: "checkout" } }
      )

      updated = original.with_tool_result(
        success: true,
        data: { entries: [{ message: "error" }] },
        execution_time_ms: 45
      )

      expect(updated.tool_result[:success]).to be true
      expect(updated.tool_result[:data][:entries]).not_to be_empty
    end
  end

  describe "#with_observation" do
    it "returns new step with observation recorded" do
      original = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs"
      )

      updated = original.with_observation("Found connection pool exhaustion")

      expect(updated.observation).to eq("Found connection pool exhaustion")
    end
  end

  describe "#completed?" do
    it "returns true when status is :completed" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        status: :completed
      )

      expect(step.completed?).to be true
    end

    it "returns false for other statuses" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        status: :executing
      )

      expect(step.completed?).to be false
    end
  end

  describe "#failed?" do
    it "returns true when status is :failed" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        status: :failed
      )

      expect(step.failed?).to be true
    end
  end

  describe "#duration_ms" do
    it "calculates duration when completed_at is set" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        created_at: Time.now - 2,
        completed_at: Time.now
      )

      expect(step.duration_ms).to be >= 2000
    end

    it "returns nil when not completed" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs"
      )

      expect(step.duration_ms).to be_nil
    end
  end

  describe "#to_h" do
    it "serializes the step" do
      step = described_class.new(
        run_id: "run-123",
        step_number: 1,
        decision: "Check logs",
        tool_call: { tool_name: "logs", params: {} },
        observation: "Found errors",
        status: :completed
      )

      hash = step.to_h

      expect(hash).to include(
        :id,
        :run_id,
        :step_number,
        :decision,
        :tool_call,
        :observation,
        :status,
        :created_at
      )
    end
  end
end
