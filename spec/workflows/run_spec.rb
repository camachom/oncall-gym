# frozen_string_literal: true

# PHASE 3: Workflow Engine - Run
#
# A Run represents a complete agent investigation of an incident.
# It contains the incident, all steps taken, and the final outcome.
#
# GUIDELINES:
# - Runs have lifecycle: started -> running -> (completed|failed|escalated)
# - Runs track total steps, safety limits, and final resolution
# - Runs aggregate all observations and the final hypothesis
# - Support pause/resume for human-in-the-loop scenarios
#
# HINTS:
# - Think about what "done" means: mitigation proposed, escalated, or gave up
# - Consider resource limits: max steps, max time, max tool calls
# - The run is the top-level unit for evaluation and replay

require "spec_helper"

RSpec.describe OncallGym::Workflows::Run do
  let(:incident) do
    double("Incident",
      id: "inc-123",
      service: "checkout",
      description: "p95 latency spike",
      severity: :high,
      to_h: { id: "inc-123", service: "checkout" }
    )
  end

  describe ".new" do
    it "creates a run for an incident" do
      run = described_class.new(incident: incident)

      expect(run.incident).to eq(incident)
      expect(run.incident_id).to eq("inc-123")
    end

    it "auto-generates an ID" do
      run = described_class.new(incident: incident)

      expect(run.id).not_to be_nil
      expect(run.id).to be_a(String)
    end

    it "defaults status to :started" do
      run = described_class.new(incident: incident)

      expect(run.status).to eq(:started)
    end

    it "accepts valid status values" do
      [:started, :running, :completed, :failed, :escalated, :paused].each do |status|
        run = described_class.new(incident: incident, status: status)
        expect(run.status).to eq(status)
      end
    end

    it "initializes with empty steps" do
      run = described_class.new(incident: incident)

      expect(run.steps).to eq([])
    end

    it "initializes with empty observations" do
      run = described_class.new(incident: incident)

      expect(run.observations).to eq([])
    end

    it "initializes with no current hypothesis" do
      run = described_class.new(incident: incident)

      expect(run.current_hypothesis).to be_nil
    end

    it "sets default safety limits" do
      run = described_class.new(incident: incident)

      expect(run.max_steps).to be > 0
      expect(run.max_steps).to be <= 50 # Reasonable default
    end

    it "accepts custom safety limits" do
      run = described_class.new(incident: incident, max_steps: 20)

      expect(run.max_steps).to eq(20)
    end

    it "records started_at timestamp" do
      before = Time.now
      run = described_class.new(incident: incident)
      after = Time.now

      expect(run.started_at).to be >= before
      expect(run.started_at).to be <= after
    end
  end

  describe "#add_step" do
    it "adds a step to the run" do
      run = described_class.new(incident: incident)
      step = double("Step", step_number: 1, status: :completed)

      updated_run = run.add_step(step)

      expect(updated_run.steps.length).to eq(1)
      expect(updated_run.steps.first).to eq(step)
    end

    it "returns a new run instance (immutability)" do
      run = described_class.new(incident: incident)
      step = double("Step", step_number: 1, status: :completed)

      updated_run = run.add_step(step)

      expect(updated_run).not_to equal(run)
      expect(run.steps).to eq([])
    end

    it "updates status to :running if currently :started" do
      run = described_class.new(incident: incident, status: :started)
      step = double("Step", step_number: 1, status: :completed)

      updated_run = run.add_step(step)

      expect(updated_run.status).to eq(:running)
    end
  end

  describe "#add_observation" do
    it "adds an observation to the run" do
      run = described_class.new(incident: incident)
      observation = double("Observation", id: "obs-1", significant: true)

      updated_run = run.add_observation(observation)

      expect(updated_run.observations.length).to eq(1)
    end
  end

  describe "#with_hypothesis" do
    it "updates the current hypothesis" do
      run = described_class.new(incident: incident)
      hypothesis = double("Hypothesis", id: "h-1", confidence: 0.7)

      updated_run = run.with_hypothesis(hypothesis)

      expect(updated_run.current_hypothesis).to eq(hypothesis)
    end
  end

  describe "#with_status" do
    it "updates the run status" do
      run = described_class.new(incident: incident, status: :running)

      updated_run = run.with_status(:completed)

      expect(updated_run.status).to eq(:completed)
    end

    it "sets completed_at when completing" do
      run = described_class.new(incident: incident, status: :running)

      updated_run = run.with_status(:completed)

      expect(updated_run.completed_at).not_to be_nil
    end
  end

  describe "#with_resolution" do
    it "sets the resolution and completes the run" do
      run = described_class.new(incident: incident, status: :running)

      updated_run = run.with_resolution(
        type: :mitigation_proposed,
        description: "Roll back to v2.3.0",
        confidence: 0.85
      )

      expect(updated_run.resolution[:type]).to eq(:mitigation_proposed)
      expect(updated_run.resolution[:description]).to eq("Roll back to v2.3.0")
      expect(updated_run.status).to eq(:completed)
    end
  end

  describe "safety limits" do
    describe "#step_limit_reached?" do
      it "returns true when max steps exceeded" do
        run = described_class.new(incident: incident, max_steps: 2)
        step1 = double("Step", step_number: 1, status: :completed)
        step2 = double("Step", step_number: 2, status: :completed)

        run = run.add_step(step1).add_step(step2)

        expect(run.step_limit_reached?).to be true
      end

      it "returns false when under limit" do
        run = described_class.new(incident: incident, max_steps: 10)
        step1 = double("Step", step_number: 1, status: :completed)

        run = run.add_step(step1)

        expect(run.step_limit_reached?).to be false
      end
    end

    describe "#can_continue?" do
      it "returns true when run can proceed" do
        run = described_class.new(incident: incident, status: :running, max_steps: 10)

        expect(run.can_continue?).to be true
      end

      it "returns false when step limit reached" do
        run = described_class.new(incident: incident, status: :running, max_steps: 0)

        expect(run.can_continue?).to be false
      end

      it "returns false when run is completed" do
        run = described_class.new(incident: incident, status: :completed)

        expect(run.can_continue?).to be false
      end

      it "returns false when run is paused" do
        run = described_class.new(incident: incident, status: :paused)

        expect(run.can_continue?).to be false
      end
    end
  end

  describe "querying state" do
    describe "#step_count" do
      it "returns the number of steps" do
        run = described_class.new(incident: incident)
        step1 = double("Step", step_number: 1, status: :completed)
        step2 = double("Step", step_number: 2, status: :completed)

        run = run.add_step(step1).add_step(step2)

        expect(run.step_count).to eq(2)
      end
    end

    describe "#last_step" do
      it "returns the most recent step" do
        run = described_class.new(incident: incident)
        step1 = double("Step", step_number: 1, status: :completed)
        step2 = double("Step", step_number: 2, status: :completed)

        run = run.add_step(step1).add_step(step2)

        expect(run.last_step).to eq(step2)
      end

      it "returns nil when no steps" do
        run = described_class.new(incident: incident)

        expect(run.last_step).to be_nil
      end
    end

    describe "#significant_observations" do
      it "returns only significant observations" do
        run = described_class.new(incident: incident)
        sig_obs = double("Observation", id: "obs-1", significant: true, significant?: true)
        normal_obs = double("Observation", id: "obs-2", significant: false, significant?: false)

        run = run.add_observation(sig_obs).add_observation(normal_obs)

        expect(run.significant_observations.length).to eq(1)
        expect(run.significant_observations.first).to eq(sig_obs)
      end
    end

    describe "#duration_seconds" do
      it "calculates total duration when completed" do
        run = described_class.new(
          incident: incident,
          started_at: Time.now - 120,
          completed_at: Time.now
        )

        expect(run.duration_seconds).to be >= 120
      end
    end
  end

  describe "#to_h" do
    it "serializes the run" do
      run = described_class.new(incident: incident)

      hash = run.to_h

      expect(hash).to include(
        :id,
        :incident_id,
        :status,
        :steps,
        :started_at,
        :max_steps
      )
    end
  end

  describe "terminal states" do
    describe "#terminal?" do
      it "returns true for completed" do
        run = described_class.new(incident: incident, status: :completed)
        expect(run.terminal?).to be true
      end

      it "returns true for failed" do
        run = described_class.new(incident: incident, status: :failed)
        expect(run.terminal?).to be true
      end

      it "returns true for escalated" do
        run = described_class.new(incident: incident, status: :escalated)
        expect(run.terminal?).to be true
      end

      it "returns false for running" do
        run = described_class.new(incident: incident, status: :running)
        expect(run.terminal?).to be false
      end
    end
  end
end
