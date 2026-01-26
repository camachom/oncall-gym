# frozen_string_literal: true

# PHASE 1: Core Domain - Hypothesis
#
# A Hypothesis represents the agent's current theory about what's wrong
# and how to fix it. Hypotheses evolve as the agent gathers evidence.
#
# GUIDELINES:
# - Hypotheses have a confidence level (0.0 to 1.0)
# - They can reference supporting observations
# - A hypothesis may include a proposed mitigation
# - Status tracks: :investigating, :supported, :refuted, :actionable
#
# HINTS:
# - Think about how a human engineer forms and revises hypotheses
# - Confidence should increase with supporting evidence
# - An "actionable" hypothesis means enough confidence to act

require "spec_helper"

RSpec.describe OncallGym::Incidents::Hypothesis do
  describe ".new" do
    it "creates a hypothesis with required fields" do
      hypothesis = described_class.new(
        description: "Database connection pool exhausted due to leaked connections"
      )

      expect(hypothesis.description).to eq("Database connection pool exhausted due to leaked connections")
    end

    it "auto-generates an ID" do
      hypothesis = described_class.new(description: "Some theory")

      expect(hypothesis.id).not_to be_nil
    end

    it "defaults confidence to 0.0" do
      hypothesis = described_class.new(description: "Untested theory")

      expect(hypothesis.confidence).to eq(0.0)
    end

    it "accepts confidence between 0.0 and 1.0" do
      hypothesis = described_class.new(
        description: "Likely theory",
        confidence: 0.75
      )

      expect(hypothesis.confidence).to eq(0.75)
    end

    it "rejects confidence outside valid range" do
      expect {
        described_class.new(description: "Bad theory", confidence: 1.5)
      }.to raise_error(OncallGym::ValidationError)

      expect {
        described_class.new(description: "Bad theory", confidence: -0.1)
      }.to raise_error(OncallGym::ValidationError)
    end

    it "defaults status to :investigating" do
      hypothesis = described_class.new(description: "New theory")

      expect(hypothesis.status).to eq(:investigating)
    end

    it "accepts valid status values" do
      statuses = [:investigating, :supported, :refuted, :actionable]

      statuses.each do |status|
        hypothesis = described_class.new(description: "Theory", status: status)
        expect(hypothesis.status).to eq(status)
      end
    end

    it "rejects invalid status" do
      expect {
        described_class.new(description: "Theory", status: :invalid)
      }.to raise_error(OncallGym::ValidationError)
    end

    it "accepts supporting observation IDs" do
      hypothesis = described_class.new(
        description: "DB issue",
        supporting_observation_ids: ["obs-1", "obs-2"]
      )

      expect(hypothesis.supporting_observation_ids).to eq(["obs-1", "obs-2"])
    end

    it "defaults supporting_observation_ids to empty array" do
      hypothesis = described_class.new(description: "Theory")

      expect(hypothesis.supporting_observation_ids).to eq([])
    end

    it "accepts an optional proposed mitigation" do
      hypothesis = described_class.new(
        description: "Connection pool exhausted",
        proposed_mitigation: "Restart the checkout-api pods to clear leaked connections"
      )

      expect(hypothesis.proposed_mitigation).to eq("Restart the checkout-api pods to clear leaked connections")
    end

    it "defaults proposed_mitigation to nil" do
      hypothesis = described_class.new(description: "Theory")

      expect(hypothesis.proposed_mitigation).to be_nil
    end
  end

  describe "#with_confidence" do
    it "returns a new hypothesis with updated confidence" do
      original = described_class.new(description: "Theory", confidence: 0.3)
      updated = original.with_confidence(0.7)

      expect(updated.confidence).to eq(0.7)
      expect(original.confidence).to eq(0.3) # Original unchanged
      expect(updated.id).to eq(original.id)
      expect(updated.description).to eq(original.description)
    end
  end

  describe "#with_status" do
    it "returns a new hypothesis with updated status" do
      original = described_class.new(description: "Theory", status: :investigating)
      updated = original.with_status(:supported)

      expect(updated.status).to eq(:supported)
      expect(original.status).to eq(:investigating)
    end
  end

  describe "#with_observation" do
    it "returns a new hypothesis with added observation ID" do
      original = described_class.new(
        description: "Theory",
        supporting_observation_ids: ["obs-1"]
      )
      updated = original.with_observation("obs-2")

      expect(updated.supporting_observation_ids).to eq(["obs-1", "obs-2"])
      expect(original.supporting_observation_ids).to eq(["obs-1"])
    end
  end

  describe "#with_mitigation" do
    it "returns a new hypothesis with proposed mitigation" do
      original = described_class.new(description: "DB pool exhausted")
      updated = original.with_mitigation("Restart pods")

      expect(updated.proposed_mitigation).to eq("Restart pods")
      expect(original.proposed_mitigation).to be_nil
    end
  end

  describe "#actionable?" do
    it "returns true when status is :actionable" do
      hypothesis = described_class.new(description: "Theory", status: :actionable)

      expect(hypothesis.actionable?).to be true
    end

    it "returns false for other statuses" do
      hypothesis = described_class.new(description: "Theory", status: :investigating)

      expect(hypothesis.actionable?).to be false
    end
  end

  describe "#high_confidence?" do
    it "returns true when confidence >= 0.8" do
      high = described_class.new(description: "Theory", confidence: 0.85)
      medium = described_class.new(description: "Theory", confidence: 0.7)

      expect(high.high_confidence?).to be true
      expect(medium.high_confidence?).to be false
    end
  end

  describe "#to_h" do
    it "serializes the hypothesis" do
      hypothesis = described_class.new(
        description: "DB issue",
        confidence: 0.8,
        status: :supported,
        supporting_observation_ids: ["obs-1"],
        proposed_mitigation: "Restart"
      )

      hash = hypothesis.to_h

      expect(hash[:description]).to eq("DB issue")
      expect(hash[:confidence]).to eq(0.8)
      expect(hash[:status]).to eq(:supported)
      expect(hash[:supporting_observation_ids]).to eq(["obs-1"])
      expect(hash[:proposed_mitigation]).to eq("Restart")
    end
  end
end
