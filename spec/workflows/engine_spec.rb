# frozen_string_literal: true

# PHASE 3: Workflow Engine - Engine
#
# The Engine executes the agent decision loop. It's the "brain" that
# coordinates tools, observations, hypotheses, and safety limits.
#
# GUIDELINES:
# - Takes an agent (decision maker) and tool registry
# - Executes one step at a time (for debuggability and control)
# - Enforces safety limits (max steps, timeouts)
# - Emits events for audit trail
#
# HINTS:
# - The agent is injected (could be AI, rule-based, or mock)
# - Think about what triggers step termination vs run termination
# - Consider how to make the engine testable without a real agent

require "spec_helper"

RSpec.describe OncallGym::Workflows::Engine do
  # Mock agent for testing
  let(:mock_agent) do
    double("Agent").tap do |agent|
      allow(agent).to receive(:decide_next_action).and_return(
        action: :call_tool,
        tool_name: "logs",
        tool_params: { service: "checkout", level: "error" },
        reasoning: "Checking error logs first to understand the failure pattern"
      )

      allow(agent).to receive(:analyze_result).and_return(
        observation: "Found repeated timeout errors to database",
        significant: true,
        hypothesis_update: {
          description: "Database connection issues causing timeouts",
          confidence: 0.6
        }
      )
    end
  end

  let(:tool_registry) do
    double("ToolRegistry").tap do |registry|
      allow(registry).to receive(:call).with("logs", anything).and_return(
        double("Result",
          success?: true,
          tool_name: "logs",
          data: { entries: [{ level: "error", message: "timeout" }] },
          execution_time_ms: 50,
          errors: []
        )
      )
    end
  end

  let(:incident) do
    double("Incident",
      id: "inc-123",
      service: "checkout",
      description: "p95 latency spike",
      to_h: { id: "inc-123" }
    )
  end

  describe ".new" do
    it "creates an engine with required dependencies" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      expect(engine.agent).to eq(mock_agent)
      expect(engine.tool_registry).to eq(tool_registry)
    end

    it "accepts optional event handler for audit" do
      events = []
      handler = ->(event) { events << event }

      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry,
        event_handler: handler
      )

      expect(engine.event_handler).to eq(handler)
    end
  end

  describe "#start_run" do
    it "creates a new run for an incident" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)

      expect(run).to be_a(OncallGym::Workflows::Run)
      expect(run.incident_id).to eq("inc-123")
      expect(run.status).to eq(:started)
    end

    it "accepts custom max_steps limit" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident, max_steps: 5)

      expect(run.max_steps).to eq(5)
    end

    it "emits a run_started event" do
      events = []
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry,
        event_handler: ->(e) { events << e }
      )

      engine.start_run(incident: incident)

      expect(events.last[:type]).to eq(:run_started)
      expect(events.last[:incident_id]).to eq("inc-123")
    end
  end

  describe "#execute_step" do
    it "executes a single step and returns updated run" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)
      updated_run = engine.execute_step(run)

      expect(updated_run.step_count).to eq(1)
      expect(updated_run.status).to eq(:running)
    end

    it "asks agent to decide next action" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)

      expect(mock_agent).to receive(:decide_next_action).with(
        incident: incident,
        observations: [],
        current_hypothesis: nil,
        step_number: 1
      )

      engine.execute_step(run)
    end

    it "calls the tool specified by the agent" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)

      expect(tool_registry).to receive(:call).with(
        "logs",
        { service: "checkout", level: "error" }
      )

      engine.execute_step(run)
    end

    it "asks agent to analyze tool result" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)

      expect(mock_agent).to receive(:analyze_result)

      engine.execute_step(run)
    end

    it "records the observation from agent analysis" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)
      updated_run = engine.execute_step(run)

      expect(updated_run.observations.length).to eq(1)
    end

    it "updates hypothesis based on agent analysis" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)
      updated_run = engine.execute_step(run)

      expect(updated_run.current_hypothesis).not_to be_nil
      expect(updated_run.current_hypothesis.confidence).to eq(0.6)
    end

    it "emits step events" do
      events = []
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry,
        event_handler: ->(e) { events << e }
      )

      run = engine.start_run(incident: incident)
      engine.execute_step(run)

      event_types = events.map { |e| e[:type] }
      expect(event_types).to include(:step_started, :tool_called, :step_completed)
    end

    it "raises WorkflowError if run cannot continue" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident, max_steps: 0)

      expect {
        engine.execute_step(run)
      }.to raise_error(OncallGym::WorkflowError, /cannot continue/)
    end
  end

  describe "agent decision handling" do
    context "when agent decides to propose mitigation" do
      let(:mitigation_agent) do
        double("Agent").tap do |agent|
          allow(agent).to receive(:decide_next_action).and_return(
            action: :propose_mitigation,
            mitigation: "Roll back checkout service to v2.3.0",
            confidence: 0.9,
            reasoning: "Evidence strongly suggests recent deploy caused the issue"
          )
        end
      end

      it "completes the run with resolution" do
        engine = described_class.new(
          agent: mitigation_agent,
          tool_registry: tool_registry
        )

        run = engine.start_run(incident: incident)
        updated_run = engine.execute_step(run)

        expect(updated_run.status).to eq(:completed)
        expect(updated_run.resolution[:type]).to eq(:mitigation_proposed)
        expect(updated_run.resolution[:description]).to include("Roll back")
      end
    end

    context "when agent decides to escalate" do
      let(:escalating_agent) do
        double("Agent").tap do |agent|
          allow(agent).to receive(:decide_next_action).and_return(
            action: :escalate,
            reason: "Unable to determine root cause, requires database team expertise",
            escalation_target: "database-oncall"
          )
        end
      end

      it "marks run as escalated" do
        engine = described_class.new(
          agent: escalating_agent,
          tool_registry: tool_registry
        )

        run = engine.start_run(incident: incident)
        updated_run = engine.execute_step(run)

        expect(updated_run.status).to eq(:escalated)
        expect(updated_run.resolution[:type]).to eq(:escalated)
      end
    end
  end

  describe "tool error handling" do
    let(:failing_registry) do
      double("ToolRegistry").tap do |registry|
        allow(registry).to receive(:call).and_return(
          double("Result",
            success?: false,
            tool_name: "logs",
            data: nil,
            errors: ["Service not found"],
            execution_time_ms: 10
          )
        )
      end
    end

    it "records tool failure in the step" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: failing_registry
      )

      allow(mock_agent).to receive(:analyze_result).and_return(
        observation: "Tool call failed, need to try different approach",
        significant: false,
        hypothesis_update: nil
      )

      run = engine.start_run(incident: incident)
      updated_run = engine.execute_step(run)

      last_step = updated_run.last_step
      expect(last_step.tool_result[:success]).to be false
    end

    it "continues execution after tool failure (agent decides what to do)" do
      engine = described_class.new(
        agent: mock_agent,
        tool_registry: failing_registry
      )

      allow(mock_agent).to receive(:analyze_result).and_return(
        observation: "Tool call failed",
        significant: false,
        hypothesis_update: nil
      )

      run = engine.start_run(incident: incident)
      updated_run = engine.execute_step(run)

      expect(updated_run.can_continue?).to be true
    end
  end

  describe "#run_to_completion" do
    it "executes steps until terminal state" do
      step_count = 0
      completing_agent = double("Agent").tap do |agent|
        allow(agent).to receive(:decide_next_action) do
          step_count += 1
          if step_count >= 3
            {
              action: :propose_mitigation,
              mitigation: "Restart the service",
              confidence: 0.85,
              reasoning: "Identified root cause"
            }
          else
            {
              action: :call_tool,
              tool_name: "logs",
              tool_params: { service: "checkout" },
              reasoning: "Investigating"
            }
          end
        end

        allow(agent).to receive(:analyze_result).and_return(
          observation: "Found more evidence",
          significant: true,
          hypothesis_update: { description: "Theory", confidence: 0.5 }
        )
      end

      engine = described_class.new(
        agent: completing_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident)
      final_run = engine.run_to_completion(run)

      expect(final_run.status).to eq(:completed)
      expect(final_run.step_count).to eq(3)
    end

    it "stops at max steps limit" do
      infinite_agent = double("Agent").tap do |agent|
        allow(agent).to receive(:decide_next_action).and_return(
          action: :call_tool,
          tool_name: "logs",
          tool_params: { service: "checkout" },
          reasoning: "Still looking..."
        )

        allow(agent).to receive(:analyze_result).and_return(
          observation: "Nothing conclusive",
          significant: false,
          hypothesis_update: nil
        )
      end

      engine = described_class.new(
        agent: infinite_agent,
        tool_registry: tool_registry
      )

      run = engine.start_run(incident: incident, max_steps: 5)
      final_run = engine.run_to_completion(run)

      expect(final_run.step_count).to eq(5)
      expect(final_run.status).to eq(:failed)
      expect(final_run.resolution[:type]).to eq(:step_limit_reached)
    end
  end
end
