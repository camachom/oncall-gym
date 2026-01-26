# frozen_string_literal: true

# INTEGRATION TEST: Full Agent Run
#
# This tests the complete flow from incident to resolution.
# Use this to verify all components work together correctly.
#
# NOTE: This test requires you to have implemented all phases.
# Run it as a final validation that everything integrates properly.

require "spec_helper"

RSpec.describe "Full Agent Run", :integration do
  # Skip this test until all components are implemented
  # Remove the skip once you've completed all phases
  before(:each) do
    skip "Implement all phases first" unless ENV["RUN_INTEGRATION"]
  end

  describe "complete incident investigation" do
    let(:scenario) do
      OncallGym::Simulator::Scenario.from_hash(
        name: "Checkout Latency Spike",
        description: "p95 latency increased after deploy",
        incident: {
          service: "checkout",
          description: "p95 latency spike above 500ms",
          severity: :high
        },
        ground_truth: {
          root_cause: "Memory leak in payment SDK",
          correct_mitigation: "Roll back to v2.3.0"
        },
        success_criteria: {
          must_identify: ["recent deploy"],
          acceptable_mitigations: ["rollback", "restart"],
          max_steps: 10
        },
        data: {
          logs: [
            { timestamp: "2024-01-15T10:30:00Z", service: "checkout", level: "error", message: "Connection timeout to payment service" },
            { timestamp: "2024-01-15T10:29:00Z", service: "checkout", level: "error", message: "Payment request failed: timeout" },
            { timestamp: "2024-01-15T10:28:00Z", service: "checkout", level: "warn", message: "Slow response from payment service: 450ms" },
            { timestamp: "2024-01-15T10:00:00Z", service: "checkout", level: "info", message: "Deploy completed: v2.3.1" }
          ],
          metrics: {
            "checkout" => {
              "latency_p95" => [
                { timestamp: "2024-01-15T10:30:00Z", value: 520 },
                { timestamp: "2024-01-15T10:25:00Z", value: 480 },
                { timestamp: "2024-01-15T10:20:00Z", value: 450 },
                { timestamp: "2024-01-15T10:15:00Z", value: 400 },
                { timestamp: "2024-01-15T10:10:00Z", value: 350 },
                { timestamp: "2024-01-15T10:05:00Z", value: 120 },
                { timestamp: "2024-01-15T10:00:00Z", value: 100 }
              ],
              "error_rate" => [
                { timestamp: "2024-01-15T10:30:00Z", value: 0.15 },
                { timestamp: "2024-01-15T10:00:00Z", value: 0.01 }
              ]
            }
          },
          deploys: [
            {
              id: "deploy-001",
              service: "checkout",
              version: "v2.3.1",
              previous_version: "v2.3.0",
              timestamp: "2024-01-15T10:00:00Z",
              author: "alice@example.com",
              status: "succeeded",
              changes: ["Updated payment SDK to v3.0"],
              rollback_available: true
            }
          ],
          runbooks: [
            {
              id: "rb-001",
              service: "checkout",
              title: "High Latency Investigation",
              symptoms: ["latency spike", "slow responses"],
              steps: [
                "Check recent deploys",
                "Review error logs",
                "Check downstream service health"
              ],
              escalation: "Page platform team"
            }
          ]
        }
      )
    end

    # A simple rule-based agent for testing
    let(:test_agent) do
      Class.new do
        def initialize
          @step = 0
          @observations = []
        end

        def decide_next_action(incident:, observations:, current_hypothesis:, step_number:)
          @observations = observations

          case step_number
          when 1
            # First, check the runbook
            {
              action: :call_tool,
              tool_name: "runbook",
              tool_params: { service: incident.service, topic: "latency" },
              reasoning: "Looking up runbook for latency issues"
            }
          when 2
            # Check recent deploys
            {
              action: :call_tool,
              tool_name: "deploys",
              tool_params: { service: incident.service, limit: 5 },
              reasoning: "Checking recent deploys as runbook suggests"
            }
          when 3
            # Check error logs
            {
              action: :call_tool,
              tool_name: "logs",
              tool_params: { service: incident.service, level: "error" },
              reasoning: "Looking for error patterns"
            }
          when 4
            # Check metrics
            {
              action: :call_tool,
              tool_name: "metrics",
              tool_params: { service: incident.service, metric_name: "latency_p95" },
              reasoning: "Checking latency metrics trend"
            }
          else
            # Propose rollback based on evidence
            {
              action: :propose_mitigation,
              mitigation: "Roll back checkout service to v2.3.0",
              confidence: 0.85,
              reasoning: "Deploy at 10:00 correlates with latency increase"
            }
          end
        end

        def analyze_result(tool_result:, incident:, current_hypothesis:)
          if tool_result.tool_name == "deploys" && tool_result.success?
            {
              observation: "Found deploy at 10:00 - v2.3.1 with payment SDK update",
              significant: true,
              hypothesis_update: {
                description: "Recent deploy may be causing latency issues",
                confidence: 0.6
              }
            }
          elsif tool_result.tool_name == "metrics" && tool_result.success?
            {
              observation: "Latency increased from 100ms to 500ms starting at 10:00",
              significant: true,
              hypothesis_update: {
                description: "Deploy at 10:00 caused latency regression",
                confidence: 0.8
              }
            }
          else
            {
              observation: "Gathered additional context",
              significant: false,
              hypothesis_update: nil
            }
          end
        end
      end.new
    end

    it "runs a complete investigation and proposes mitigation" do
      engine = OncallGym::Workflows::Engine.new(
        agent: test_agent,
        tool_registry: scenario.tool_registry
      )

      run = engine.start_run(incident: scenario.incident, max_steps: 10)
      final_run = engine.run_to_completion(run)

      expect(final_run.status).to eq(:completed)
      expect(final_run.resolution[:type]).to eq(:mitigation_proposed)
      expect(final_run.resolution[:description]).to include("Roll back")
    end

    it "evaluates the run against ground truth" do
      engine = OncallGym::Workflows::Engine.new(
        agent: test_agent,
        tool_registry: scenario.tool_registry
      )

      run = engine.start_run(incident: scenario.incident)
      final_run = engine.run_to_completion(run)

      evaluation = scenario.evaluate(final_run)

      expect(evaluation[:success]).to be true
      expect(evaluation[:score]).to be > 0.5
    end

    it "records complete audit trail" do
      events = []
      engine = OncallGym::Workflows::Engine.new(
        agent: test_agent,
        tool_registry: scenario.tool_registry,
        event_handler: ->(e) { events << e }
      )

      run = engine.start_run(incident: scenario.incident)
      engine.run_to_completion(run)

      event_types = events.map { |e| e[:type] }

      expect(event_types).to include(:run_started)
      expect(event_types).to include(:tool_called)
      expect(event_types).to include(:observation_recorded)
      expect(event_types).to include(:run_completed)
    end
  end

  describe "safety limits" do
    let(:infinite_loop_agent) do
      Class.new do
        def decide_next_action(**_)
          {
            action: :call_tool,
            tool_name: "logs",
            tool_params: { service: "checkout" },
            reasoning: "Still investigating..."
          }
        end

        def analyze_result(**_)
          {
            observation: "Need more data",
            significant: false,
            hypothesis_update: nil
          }
        end
      end.new
    end

    it "stops at max steps and marks run as failed" do
      simple_scenario = OncallGym::Simulator::Scenario.from_hash(
        name: "Test",
        incident: { service: "checkout", description: "test" },
        ground_truth: { root_cause: "test" },
        data: { logs: [], metrics: {}, deploys: [], runbooks: [] }
      )

      engine = OncallGym::Workflows::Engine.new(
        agent: infinite_loop_agent,
        tool_registry: simple_scenario.tool_registry
      )

      run = engine.start_run(incident: simple_scenario.incident, max_steps: 3)
      final_run = engine.run_to_completion(run)

      expect(final_run.step_count).to eq(3)
      expect(final_run.status).to eq(:failed)
      expect(final_run.resolution[:type]).to eq(:step_limit_reached)
    end
  end

  describe "escalation handling" do
    let(:escalating_agent) do
      Class.new do
        def decide_next_action(**_)
          {
            action: :escalate,
            reason: "Cannot determine root cause",
            escalation_target: "platform-oncall"
          }
        end

        def analyze_result(**_)
          {}
        end
      end.new
    end

    it "handles agent escalation requests" do
      simple_scenario = OncallGym::Simulator::Scenario.from_hash(
        name: "Test",
        incident: { service: "checkout", description: "test" },
        ground_truth: { root_cause: "test" },
        data: { logs: [], metrics: {}, deploys: [], runbooks: [] }
      )

      engine = OncallGym::Workflows::Engine.new(
        agent: escalating_agent,
        tool_registry: simple_scenario.tool_registry
      )

      run = engine.start_run(incident: simple_scenario.incident)
      final_run = engine.run_to_completion(run)

      expect(final_run.status).to eq(:escalated)
      expect(final_run.resolution[:type]).to eq(:escalated)
    end
  end
end
