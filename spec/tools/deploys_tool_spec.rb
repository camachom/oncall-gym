# frozen_string_literal: true

# PHASE 2: Tool System - Deploys Tool
#
# The DeploysTool retrieves recent deployment history.
# Critical for identifying if an incident correlates with a recent change.
#
# GUIDELINES:
# - Accepts: service, limit, time_range
# - Returns: list of deploys with version, timestamp, author, changes
# - Should highlight "recent" deploys that might be suspects
# - Include rollback information if available
#
# HINTS:
# - Deploys within 1 hour of incident are prime suspects
# - Include commit/PR links for traceability
# - Consider deploy status: succeeded, failed, rolled_back

require "spec_helper"

RSpec.describe OncallGym::Tools::DeploysTool do
  let(:data_source) do
    double("DataSource", deploys: [
      {
        id: "deploy-001",
        service: "checkout",
        version: "v2.3.1",
        previous_version: "v2.3.0",
        timestamp: "2024-01-15T10:00:00Z",
        author: "alice@example.com",
        status: "succeeded",
        changes: ["Updated payment processor SDK", "Added retry logic"],
        commit_sha: "abc123",
        rollback_available: true
      },
      {
        id: "deploy-002",
        service: "checkout",
        version: "v2.3.0",
        previous_version: "v2.2.9",
        timestamp: "2024-01-14T15:00:00Z",
        author: "bob@example.com",
        status: "succeeded",
        changes: ["Bug fix for cart calculation"],
        commit_sha: "def456",
        rollback_available: true
      },
      {
        id: "deploy-003",
        service: "inventory",
        version: "v1.5.0",
        previous_version: "v1.4.9",
        timestamp: "2024-01-15T09:00:00Z",
        author: "charlie@example.com",
        status: "succeeded",
        changes: ["Database migration"],
        commit_sha: "ghi789",
        rollback_available: false
      }
    ])
  end

  let(:tool) { described_class.new(data_source: data_source) }

  describe ".tool_name" do
    it "returns 'deploys'" do
      expect(described_class.tool_name).to eq("deploys")
    end
  end

  describe "#call" do
    it "requires a service parameter" do
      result = tool.call({})

      expect(result.success?).to be false
      expect(result.errors).to include(/service/)
    end

    it "returns deploys for the specified service" do
      result = tool.call(service: "checkout")

      expect(result.success?).to be true
      expect(result.data[:deploys]).to all(include(service: "checkout"))
      expect(result.data[:deploys].length).to eq(2)
    end

    it "returns deploys sorted by timestamp descending" do
      result = tool.call(service: "checkout")

      timestamps = result.data[:deploys].map { |d| d[:timestamp] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it "includes relevant deploy information" do
      result = tool.call(service: "checkout")
      deploy = result.data[:deploys].first

      expect(deploy).to include(
        :id,
        :version,
        :previous_version,
        :timestamp,
        :author,
        :status,
        :changes,
        :rollback_available
      )
    end

    it "limits the number of results" do
      result = tool.call(service: "checkout", limit: 1)

      expect(result.data[:deploys].length).to eq(1)
    end

    it "defaults limit to 10" do
      result = tool.call(service: "checkout")

      expect(result.success?).to be true
    end

    it "returns empty array for service with no deploys" do
      result = tool.call(service: "unknown-service")

      expect(result.success?).to be true
      expect(result.data[:deploys]).to eq([])
    end

    it "includes summary information" do
      result = tool.call(service: "checkout")

      expect(result.data[:total_deploys]).to eq(2)
      expect(result.data[:latest_deploy]).to eq("v2.3.1")
    end

    it "highlights recent deploys as potential suspects" do
      # Assuming incident time is passed or inferred
      result = tool.call(service: "checkout", since: "2024-01-15T09:30:00Z")

      suspect_deploys = result.data[:deploys].select { |d| d[:potential_suspect] }
      expect(suspect_deploys.length).to be >= 1
    end
  end

  describe "rollback information" do
    it "indicates which deploys can be rolled back" do
      result = tool.call(service: "checkout")

      rollbackable = result.data[:deploys].select { |d| d[:rollback_available] }
      expect(rollbackable).not_to be_empty
    end
  end
end
