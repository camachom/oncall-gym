# frozen_string_literal: true

# PHASE 4: Simulator - Scenario
#
# A Scenario is a complete incident setup with known ground truth.
# It bundles an incident, fixture data, and expected resolution.
#
# GUIDELINES:
# - Scenarios are the "test cases" for agent evaluation
# - Include ground truth: what actually caused the incident
# - Define success criteria for agent behavior
# - Support tagging for filtering (difficulty, type, skills needed)
#
# HINTS:
# - Think of scenarios as integration test fixtures
# - Ground truth enables automated evaluation
# - Consider partial credit for getting close to the answer

require "spec_helper"

RSpec.describe OncallGym::Simulator::Scenario do
  describe ".load" do
    it "loads a scenario from a fixture directory" do
      # Uses real fixture - create it first!
      scenario = described_class.load(fixture_path("incidents/latency_spike"))

      expect(scenario).to be_a(described_class)
      expect(scenario.name).not_to be_nil
    end

    it "raises error if scenario.json is missing" do
      expect {
        described_class.load("/tmp/empty_dir")
      }.to raise_error(OncallGym::Error, /scenario.*not found/i)
    end
  end

  describe ".from_hash" do
    let(:scenario_data) do
      {
        name: "Checkout Latency Spike",
        description: "p95 latency increased 4x after a deploy",
        difficulty: "medium",
        tags: ["latency", "deploy", "rollback"],
        incident: {
          service: "checkout",
          description: "p95 latency spike above 500ms",
          severity: "high"
        },
        ground_truth: {
          root_cause: "Memory leak in payment SDK v2.3.1",
          correct_mitigation: "Roll back to v2.3.0",
          key_evidence: [
            "Latency increased right after deploy at 10:00",
            "Error logs show connection timeouts",
            "Memory metrics show steady increase"
          ]
        },
        success_criteria: {
          must_identify: ["recent deploy as suspect"],
          acceptable_mitigations: ["rollback", "restart pods"],
          max_steps: 10
        }
      }
    end

    it "creates a scenario from hash data" do
      scenario = described_class.from_hash(scenario_data)

      expect(scenario.name).to eq("Checkout Latency Spike")
      expect(scenario.difficulty).to eq("medium")
    end

    it "creates an incident from the scenario" do
      scenario = described_class.from_hash(scenario_data)

      expect(scenario.incident).to be_a(OncallGym::Incidents::Incident)
      expect(scenario.incident.service).to eq("checkout")
    end

    it "stores ground truth" do
      scenario = described_class.from_hash(scenario_data)

      expect(scenario.ground_truth[:root_cause]).to include("Memory leak")
      expect(scenario.ground_truth[:correct_mitigation]).to include("Roll back")
    end

    it "stores success criteria" do
      scenario = described_class.from_hash(scenario_data)

      expect(scenario.success_criteria[:max_steps]).to eq(10)
    end

    it "provides access to tags" do
      scenario = described_class.from_hash(scenario_data)

      expect(scenario.tags).to include("latency", "deploy")
    end
  end

  describe "#data_store" do
    it "returns the data store for this scenario" do
      scenario_data = {
        name: "Test",
        incident: { service: "test", description: "test" },
        ground_truth: { root_cause: "test" },
        data: {
          logs: [{ service: "test", message: "error" }],
          metrics: {},
          deploys: [],
          runbooks: []
        }
      }

      scenario = described_class.from_hash(scenario_data)
      store = scenario.data_store

      expect(store).to be_a(OncallGym::Simulator::DataStore)
      expect(store.logs.length).to eq(1)
    end
  end

  describe "#evaluate" do
    let(:scenario_data) do
      {
        name: "Test Scenario",
        incident: { service: "checkout", description: "latency spike" },
        ground_truth: {
          root_cause: "Bad deploy",
          correct_mitigation: "Rollback to v2.3.0",
          key_evidence: ["deploy correlation", "memory leak"]
        },
        success_criteria: {
          must_identify: ["recent deploy"],
          acceptable_mitigations: ["rollback", "restart"],
          max_steps: 10
        }
      }
    end

    let(:scenario) { described_class.from_hash(scenario_data) }

    it "evaluates a successful run" do
      run = double("Run",
        status: :completed,
        step_count: 5,
        resolution: {
          type: :mitigation_proposed,
          description: "Rollback to v2.3.0"
        },
        observations: [
          double(summary: "Found recent deploy at 10:00", significant?: true)
        ],
        current_hypothesis: double(
          description: "Recent deploy caused memory leak",
          confidence: 0.85
        )
      )

      result = scenario.evaluate(run)

      expect(result[:success]).to be true
      expect(result[:score]).to be > 0
    end

    it "evaluates a failed run" do
      run = double("Run",
        status: :failed,
        step_count: 10,
        resolution: { type: :step_limit_reached },
        observations: [],
        current_hypothesis: nil
      )

      result = scenario.evaluate(run)

      expect(result[:success]).to be false
    end

    it "provides detailed scoring breakdown" do
      run = double("Run",
        status: :completed,
        step_count: 5,
        resolution: {
          type: :mitigation_proposed,
          description: "Restart the pods"
        },
        observations: [
          double(summary: "Found errors in logs", significant?: true)
        ],
        current_hypothesis: double(
          description: "Some issue",
          confidence: 0.7
        )
      )

      result = scenario.evaluate(run)

      expect(result).to include(
        :success,
        :score,
        :breakdown
      )

      expect(result[:breakdown]).to include(
        :mitigation_score,
        :evidence_score,
        :efficiency_score
      )
    end

    it "awards partial credit for acceptable but not optimal mitigation" do
      run = double("Run",
        status: :completed,
        step_count: 5,
        resolution: {
          type: :mitigation_proposed,
          description: "Restart all pods"  # Acceptable but not optimal
        },
        observations: [],
        current_hypothesis: double(description: "x", confidence: 0.8)
      )

      result = scenario.evaluate(run)

      expect(result[:breakdown][:mitigation_score]).to be > 0
      expect(result[:breakdown][:mitigation_score]).to be < 1.0
    end

    it "scores based on efficiency (fewer steps is better)" do
      fast_run = double("Run",
        status: :completed,
        step_count: 3,
        resolution: { type: :mitigation_proposed, description: "Rollback" },
        observations: [],
        current_hypothesis: double(description: "x", confidence: 0.8)
      )

      slow_run = double("Run",
        status: :completed,
        step_count: 9,
        resolution: { type: :mitigation_proposed, description: "Rollback" },
        observations: [],
        current_hypothesis: double(description: "x", confidence: 0.8)
      )

      fast_result = scenario.evaluate(fast_run)
      slow_result = scenario.evaluate(slow_run)

      expect(fast_result[:breakdown][:efficiency_score]).to be > slow_result[:breakdown][:efficiency_score]
    end
  end

  describe "#tool_registry" do
    it "returns a registry with tools backed by scenario data" do
      scenario_data = {
        name: "Test",
        incident: { service: "test", description: "test" },
        ground_truth: { root_cause: "test" },
        data: {
          logs: [],
          metrics: {},
          deploys: [],
          runbooks: []
        }
      }

      scenario = described_class.from_hash(scenario_data)
      registry = scenario.tool_registry

      expect(registry.tool_names).to include("logs", "metrics", "deploys", "runbook")
    end
  end
end
