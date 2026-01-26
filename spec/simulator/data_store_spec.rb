# frozen_string_literal: true

# PHASE 4: Simulator - Data Store
#
# The DataStore provides access to simulated production data.
# It backs the tools with realistic logs, metrics, deploys, and runbooks.
#
# GUIDELINES:
# - Loads data from fixture files (JSON/YAML)
# - Provides query methods that tools use
# - Supports filtering, time ranges, and pagination
# - Is stateless (doesn't modify fixture data)
#
# HINTS:
# - Think of this as the "database" for the simulated environment
# - Consider how to make fixtures easy to create and modify
# - Support both file-based and in-memory fixtures for testing

require "spec_helper"

RSpec.describe OncallGym::Simulator::DataStore do
  describe ".from_fixtures" do
    it "loads data from fixture directory" do
      # This test uses real fixtures - create them first!
      store = described_class.from_fixtures(fixture_path("incidents/latency_spike"))

      expect(store).to be_a(described_class)
    end

    it "raises error if fixture directory doesn't exist" do
      expect {
        described_class.from_fixtures("/nonexistent/path")
      }.to raise_error(OncallGym::Error, /not found/)
    end
  end

  describe ".from_hash" do
    it "creates a store from in-memory data" do
      data = {
        logs: [{ service: "checkout", message: "error" }],
        metrics: {},
        deploys: [],
        runbooks: []
      }

      store = described_class.from_hash(data)

      expect(store.logs).to eq(data[:logs])
    end
  end

  describe "#logs" do
    let(:store) do
      described_class.from_hash(
        logs: [
          { timestamp: "2024-01-15T10:30:00Z", service: "checkout", level: "error", message: "timeout" },
          { timestamp: "2024-01-15T10:29:00Z", service: "checkout", level: "info", message: "request" },
          { timestamp: "2024-01-15T10:28:00Z", service: "inventory", level: "error", message: "sync failed" }
        ],
        metrics: {},
        deploys: [],
        runbooks: []
      )
    end

    it "returns all logs when no filters" do
      logs = store.logs

      expect(logs.length).to eq(3)
    end

    it "filters by service" do
      logs = store.logs(service: "checkout")

      expect(logs.length).to eq(2)
      expect(logs).to all(include(service: "checkout"))
    end

    it "filters by level" do
      logs = store.logs(level: "error")

      expect(logs.length).to eq(2)
    end

    it "filters by keyword in message" do
      logs = store.logs(keyword: "timeout")

      expect(logs.length).to eq(1)
    end

    it "combines filters" do
      logs = store.logs(service: "checkout", level: "error")

      expect(logs.length).to eq(1)
    end

    it "limits results" do
      logs = store.logs(limit: 2)

      expect(logs.length).to eq(2)
    end

    it "returns logs sorted by timestamp descending" do
      logs = store.logs

      timestamps = logs.map { |l| l[:timestamp] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end

  describe "#metrics" do
    let(:store) do
      described_class.from_hash(
        logs: [],
        metrics: {
          "checkout" => {
            "latency_p95" => [
              { timestamp: "2024-01-15T10:30:00Z", value: 500 },
              { timestamp: "2024-01-15T10:25:00Z", value: 450 }
            ],
            "error_rate" => [
              { timestamp: "2024-01-15T10:30:00Z", value: 0.15 }
            ]
          },
          "inventory" => {
            "latency_p95" => [
              { timestamp: "2024-01-15T10:30:00Z", value: 100 }
            ]
          }
        },
        deploys: [],
        runbooks: []
      )
    end

    it "returns metrics for a service and metric name" do
      metrics = store.metrics(service: "checkout", metric_name: "latency_p95")

      expect(metrics.length).to eq(2)
    end

    it "returns empty array for unknown service" do
      metrics = store.metrics(service: "unknown", metric_name: "latency_p95")

      expect(metrics).to eq([])
    end

    it "returns empty array for unknown metric" do
      metrics = store.metrics(service: "checkout", metric_name: "unknown")

      expect(metrics).to eq([])
    end

    it "lists available metrics for a service" do
      available = store.available_metrics(service: "checkout")

      expect(available).to contain_exactly("latency_p95", "error_rate")
    end

    it "lists all services" do
      services = store.services

      expect(services).to contain_exactly("checkout", "inventory")
    end
  end

  describe "#deploys" do
    let(:store) do
      described_class.from_hash(
        logs: [],
        metrics: {},
        deploys: [
          { id: "d1", service: "checkout", version: "v2.3.1", timestamp: "2024-01-15T10:00:00Z" },
          { id: "d2", service: "checkout", version: "v2.3.0", timestamp: "2024-01-14T15:00:00Z" },
          { id: "d3", service: "inventory", version: "v1.5.0", timestamp: "2024-01-15T09:00:00Z" }
        ],
        runbooks: []
      )
    end

    it "returns deploys for a service" do
      deploys = store.deploys(service: "checkout")

      expect(deploys.length).to eq(2)
    end

    it "returns deploys sorted by timestamp descending" do
      deploys = store.deploys(service: "checkout")

      expect(deploys.first[:version]).to eq("v2.3.1")
    end

    it "limits results" do
      deploys = store.deploys(service: "checkout", limit: 1)

      expect(deploys.length).to eq(1)
    end

    it "filters by time range" do
      deploys = store.deploys(service: "checkout", since: "2024-01-15T00:00:00Z")

      expect(deploys.length).to eq(1)
      expect(deploys.first[:version]).to eq("v2.3.1")
    end
  end

  describe "#runbooks" do
    let(:store) do
      described_class.from_hash(
        logs: [],
        metrics: {},
        deploys: [],
        runbooks: [
          {
            id: "rb1",
            service: "checkout",
            title: "High Latency",
            symptoms: ["latency spike", "slow responses"],
            steps: ["Check logs", "Check deploys"]
          },
          {
            id: "rb2",
            service: "checkout",
            title: "Payment Failures",
            symptoms: ["payment errors"],
            steps: ["Check Stripe"]
          }
        ]
      )
    end

    it "returns runbooks for a service" do
      runbooks = store.runbooks(service: "checkout")

      expect(runbooks.length).to eq(2)
    end

    it "searches by topic in title" do
      runbooks = store.runbooks(service: "checkout", topic: "latency")

      expect(runbooks.length).to eq(1)
      expect(runbooks.first[:title]).to include("Latency")
    end

    it "searches by topic in symptoms" do
      runbooks = store.runbooks(service: "checkout", topic: "slow")

      expect(runbooks.length).to eq(1)
    end

    it "performs case-insensitive search" do
      runbooks = store.runbooks(service: "checkout", topic: "LATENCY")

      expect(runbooks.length).to eq(1)
    end
  end
end
