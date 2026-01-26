# frozen_string_literal: true

# PHASE 1: Core Domain - Incident
#
# An Incident represents an alert that triggered the agent workflow.
# It captures the initial signal and metadata about what went wrong.
#
# GUIDELINES:
# - Use dry-struct for type safety (or plain Ruby with attr_reader)
# - Incidents are immutable value objects
# - ID should be auto-generated if not provided
# - Severity must be one of: :critical, :high, :medium, :low
# - Created_at defaults to current time
#
# HINTS:
# - Consider using SecureRandom.uuid for IDs
# - The service and description are required fields
# - Think about what metadata an on-call engineer needs at-a-glance

require "spec_helper"

RSpec.describe OncallGym::Incidents::Incident do
  describe ".new" do
    it "creates an incident with required fields" do
      incident = described_class.new(
        service: "checkout-api",
        description: "p95 latency spike above 500ms"
      )

      expect(incident.service).to eq("checkout-api")
      expect(incident.description).to eq("p95 latency spike above 500ms")
    end

    it "auto-generates an ID if not provided" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike"
      )

      expect(incident.id).not_to be_nil
      expect(incident.id).to be_a(String)
      expect(incident.id.length).to be > 0
    end

    it "accepts an explicit ID" do
      incident = described_class.new(
        id: "inc-123",
        service: "checkout-api",
        description: "latency spike"
      )

      expect(incident.id).to eq("inc-123")
    end

    it "defaults severity to :high" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike"
      )

      expect(incident.severity).to eq(:high)
    end

    it "accepts custom severity" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike",
        severity: :critical
      )

      expect(incident.severity).to eq(:critical)
    end

    it "validates severity is one of allowed values" do
      expect {
        described_class.new(
          service: "checkout-api",
          description: "latency spike",
          severity: :invalid
        )
      }.to raise_error(OncallGym::ValidationError)
    end

    it "sets created_at to current time by default" do
      before = Time.now
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike"
      )
      after = Time.now

      expect(incident.created_at).to be >= before
      expect(incident.created_at).to be <= after
    end

    it "accepts optional tags as a hash" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike",
        tags: { region: "us-east-1", tier: "production" }
      )

      expect(incident.tags[:region]).to eq("us-east-1")
      expect(incident.tags[:tier]).to eq("production")
    end

    it "defaults tags to empty hash" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike"
      )

      expect(incident.tags).to eq({})
    end
  end

  describe "#to_h" do
    it "serializes the incident to a hash" do
      incident = described_class.new(
        id: "inc-456",
        service: "checkout-api",
        description: "latency spike",
        severity: :critical,
        tags: { region: "us-east-1" }
      )

      hash = incident.to_h

      expect(hash[:id]).to eq("inc-456")
      expect(hash[:service]).to eq("checkout-api")
      expect(hash[:description]).to eq("latency spike")
      expect(hash[:severity]).to eq(:critical)
      expect(hash[:tags]).to eq({ region: "us-east-1" })
      expect(hash[:created_at]).to be_a(Time)
    end
  end

  describe "immutability" do
    it "does not allow modification after creation" do
      incident = described_class.new(
        service: "checkout-api",
        description: "latency spike"
      )

      expect { incident.service = "other" }.to raise_error(NoMethodError)
    end
  end
end
