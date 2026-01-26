# frozen_string_literal: true

# PHASE 2: Tool System - Metrics Tool
#
# The MetricsTool queries simulated time-series metrics.
# Essential for understanding performance degradation and capacity issues.
#
# GUIDELINES:
# - Accepts: service, metric_name, duration, aggregation
# - Returns: datapoints with timestamp and value, plus summary stats
# - Common metrics: latency_p95, error_rate, request_count, cpu, memory
# - Duration format: "5m", "1h", "24h"
#
# HINTS:
# - Aggregations: avg, max, min, sum, count
# - Consider returning both raw datapoints and summary statistics
# - Think about what metrics patterns indicate problems

require "spec_helper"

RSpec.describe OncallGym::Tools::MetricsTool do
  let(:data_source) do
    double("DataSource", metrics: {
      "checkout" => {
        "latency_p95" => [
          { timestamp: "2024-01-15T10:30:00Z", value: 450 },
          { timestamp: "2024-01-15T10:25:00Z", value: 520 },
          { timestamp: "2024-01-15T10:20:00Z", value: 480 },
          { timestamp: "2024-01-15T10:15:00Z", value: 150 },
          { timestamp: "2024-01-15T10:10:00Z", value: 120 }
        ],
        "error_rate" => [
          { timestamp: "2024-01-15T10:30:00Z", value: 0.15 },
          { timestamp: "2024-01-15T10:25:00Z", value: 0.12 },
          { timestamp: "2024-01-15T10:20:00Z", value: 0.08 },
          { timestamp: "2024-01-15T10:15:00Z", value: 0.01 },
          { timestamp: "2024-01-15T10:10:00Z", value: 0.01 }
        ]
      }
    })
  end

  let(:tool) { described_class.new(data_source: data_source) }

  describe ".tool_name" do
    it "returns 'metrics'" do
      expect(described_class.tool_name).to eq("metrics")
    end
  end

  describe "#call" do
    it "requires service and metric_name parameters" do
      result = tool.call({})
      expect(result.success?).to be false
      expect(result.errors).to include(/service/)

      result = tool.call(service: "checkout")
      expect(result.success?).to be false
      expect(result.errors).to include(/metric_name/)
    end

    it "returns datapoints for the specified metric" do
      result = tool.call(service: "checkout", metric_name: "latency_p95")

      expect(result.success?).to be true
      expect(result.data[:datapoints]).to be_an(Array)
      expect(result.data[:datapoints].first).to include(:timestamp, :value)
    end

    it "returns summary statistics" do
      result = tool.call(service: "checkout", metric_name: "latency_p95")

      expect(result.data[:summary]).to include(
        :min,
        :max,
        :avg,
        :current
      )
    end

    it "calculates correct summary stats" do
      result = tool.call(service: "checkout", metric_name: "latency_p95")
      summary = result.data[:summary]

      expect(summary[:min]).to eq(120)
      expect(summary[:max]).to eq(520)
      expect(summary[:current]).to eq(450) # Most recent
    end

    it "defaults duration to 1h" do
      result = tool.call(service: "checkout", metric_name: "latency_p95")

      expect(result.success?).to be true
      # Implementation should filter based on duration
    end

    it "accepts custom duration" do
      result = tool.call(service: "checkout", metric_name: "latency_p95", duration: "30m")

      expect(result.success?).to be true
    end

    it "validates duration format" do
      result = tool.call(service: "checkout", metric_name: "latency_p95", duration: "invalid")

      expect(result.success?).to be false
      expect(result.errors).to include(/duration/)
    end

    it "returns error for unknown service" do
      result = tool.call(service: "unknown", metric_name: "latency_p95")

      expect(result.success?).to be false
      expect(result.errors).to include(/service.*not found/i)
    end

    it "returns error for unknown metric" do
      result = tool.call(service: "checkout", metric_name: "unknown_metric")

      expect(result.success?).to be false
      expect(result.errors).to include(/metric.*not found/i)
    end

    it "includes metric metadata in response" do
      result = tool.call(service: "checkout", metric_name: "latency_p95")

      expect(result.data[:metric_name]).to eq("latency_p95")
      expect(result.data[:service]).to eq("checkout")
      expect(result.data[:duration]).to be_a(String)
    end
  end

  describe "available_metrics" do
    it "can list available metrics for a service" do
      result = tool.call(service: "checkout", metric_name: "_list")

      expect(result.success?).to be true
      expect(result.data[:available_metrics]).to include("latency_p95", "error_rate")
    end
  end
end
