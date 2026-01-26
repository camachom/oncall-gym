# frozen_string_literal: true

# PHASE 2: Tool System - Runbook Tool
#
# The RunbookTool retrieves operational runbooks for services.
# Runbooks contain documented procedures for handling known issues.
#
# GUIDELINES:
# - Accepts: service, topic (optional keyword search)
# - Returns: matching runbook entries with title, content, steps
# - Should support fuzzy matching on symptoms/keywords
# - Include severity and escalation paths
#
# HINTS:
# - Runbooks are the "institutional knowledge" of the team
# - Think about what makes a runbook actionable during an incident
# - Consider linking symptoms to specific runbooks

require "spec_helper"

RSpec.describe OncallGym::Tools::RunbookTool do
  let(:data_source) do
    double("DataSource", runbooks: [
      {
        id: "rb-001",
        service: "checkout",
        title: "High Latency Investigation",
        symptoms: ["p95 latency spike", "slow responses", "timeout errors"],
        severity: "high",
        steps: [
          "Check recent deploys for changes",
          "Review database connection pool metrics",
          "Check downstream service health",
          "Consider enabling circuit breaker if external dependency is failing"
        ],
        escalation: "Page database team if connection pool exhausted",
        last_updated: "2024-01-10"
      },
      {
        id: "rb-002",
        service: "checkout",
        title: "Payment Processing Failures",
        symptoms: ["payment errors", "transaction failures", "stripe errors"],
        severity: "critical",
        steps: [
          "Check Stripe status page",
          "Review payment service logs for error patterns",
          "Verify API keys are valid",
          "Enable fallback payment processor if available"
        ],
        escalation: "Page payments team immediately",
        last_updated: "2024-01-08"
      },
      {
        id: "rb-003",
        service: "inventory",
        title: "Stock Sync Failures",
        symptoms: ["inventory mismatch", "overselling", "stock errors"],
        severity: "high",
        steps: [
          "Check warehouse API connectivity",
          "Review sync job logs",
          "Trigger manual sync if needed"
        ],
        escalation: "Contact warehouse ops team",
        last_updated: "2024-01-05"
      }
    ])
  end

  let(:tool) { described_class.new(data_source: data_source) }

  describe ".tool_name" do
    it "returns 'runbook'" do
      expect(described_class.tool_name).to eq("runbook")
    end
  end

  describe "#call" do
    it "requires a service parameter" do
      result = tool.call({})

      expect(result.success?).to be false
      expect(result.errors).to include(/service/)
    end

    it "returns all runbooks for a service when no topic specified" do
      result = tool.call(service: "checkout")

      expect(result.success?).to be true
      expect(result.data[:runbooks].length).to eq(2)
    end

    it "searches runbooks by topic/keyword" do
      result = tool.call(service: "checkout", topic: "latency")

      expect(result.success?).to be true
      expect(result.data[:runbooks].length).to eq(1)
      expect(result.data[:runbooks].first[:title]).to include("Latency")
    end

    it "matches against symptoms" do
      result = tool.call(service: "checkout", topic: "timeout")

      expect(result.success?).to be true
      expect(result.data[:runbooks].length).to eq(1)
      expect(result.data[:runbooks].first[:symptoms]).to include("timeout errors")
    end

    it "returns runbook with actionable steps" do
      result = tool.call(service: "checkout", topic: "latency")
      runbook = result.data[:runbooks].first

      expect(runbook[:steps]).to be_an(Array)
      expect(runbook[:steps].length).to be > 0
      expect(runbook[:steps].first).to be_a(String)
    end

    it "includes escalation information" do
      result = tool.call(service: "checkout", topic: "latency")
      runbook = result.data[:runbooks].first

      expect(runbook[:escalation]).to be_a(String)
      expect(runbook[:severity]).to be_a(String)
    end

    it "returns empty array when no matching runbooks" do
      result = tool.call(service: "checkout", topic: "nonexistent-issue")

      expect(result.success?).to be true
      expect(result.data[:runbooks]).to eq([])
    end

    it "returns empty array for unknown service" do
      result = tool.call(service: "unknown-service")

      expect(result.success?).to be true
      expect(result.data[:runbooks]).to eq([])
    end

    it "performs case-insensitive search" do
      result = tool.call(service: "checkout", topic: "LATENCY")

      expect(result.success?).to be true
      expect(result.data[:runbooks].length).to eq(1)
    end

    it "includes metadata about the search" do
      result = tool.call(service: "checkout", topic: "latency")

      expect(result.data[:service]).to eq("checkout")
      expect(result.data[:query]).to eq("latency")
      expect(result.data[:total_matches]).to eq(1)
    end
  end

  describe "relevance scoring" do
    it "ranks runbooks by relevance when searching" do
      # When multiple runbooks match, most relevant should be first
      result = tool.call(service: "checkout", topic: "errors")

      expect(result.success?).to be true
      # Both runbooks mention errors in symptoms
      expect(result.data[:runbooks].first).to have_key(:relevance_score)
    end
  end
end
