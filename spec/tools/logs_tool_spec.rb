# frozen_string_literal: true

# PHASE 2: Tool System - Logs Tool
#
# The LogsTool searches simulated application logs.
# This is typically the first tool an agent uses to understand an incident.
#
# GUIDELINES:
# - Accepts: service, level, time_range, keyword, limit
# - Returns: array of log entries with timestamp, level, message
# - Should filter by the provided parameters
# - Data comes from the simulator (injected as dependency)
#
# HINTS:
# - Log levels: debug, info, warn, error, fatal
# - Time range format: "15m", "1h", "24h"
# - Think about what makes logs useful for debugging

require "spec_helper"

RSpec.describe OncallGym::Tools::LogsTool do
  # Mock data source for testing
  let(:data_source) do
    double("DataSource", logs: [
      { timestamp: "2024-01-15T10:30:00Z", level: "error", service: "checkout", message: "Connection timeout to database" },
      { timestamp: "2024-01-15T10:30:01Z", level: "error", service: "checkout", message: "Failed to process payment" },
      { timestamp: "2024-01-15T10:30:02Z", level: "info", service: "checkout", message: "Retry attempt 1" },
      { timestamp: "2024-01-15T10:29:00Z", level: "info", service: "inventory", message: "Stock updated" },
      { timestamp: "2024-01-15T10:28:00Z", level: "warn", service: "checkout", message: "Slow query detected" }
    ])
  end

  let(:tool) { described_class.new(data_source: data_source) }

  describe ".tool_name" do
    it "returns 'logs'" do
      expect(described_class.tool_name).to eq("logs")
    end
  end

  describe ".description" do
    it "describes the tool's purpose" do
      expect(described_class.description).to include("log")
    end
  end

  describe "#call" do
    it "requires a service parameter" do
      result = tool.call({})

      expect(result.success?).to be false
      expect(result.errors).to include(/service/)
    end

    it "returns logs for the specified service" do
      result = tool.call(service: "checkout")

      expect(result.success?).to be true
      expect(result.data[:entries]).to all(include(service: "checkout"))
    end

    it "filters by log level" do
      result = tool.call(service: "checkout", level: "error")

      expect(result.success?).to be true
      expect(result.data[:entries]).to all(include(level: "error"))
      expect(result.data[:entries].length).to eq(2)
    end

    it "filters by keyword in message" do
      result = tool.call(service: "checkout", keyword: "timeout")

      expect(result.success?).to be true
      expect(result.data[:entries].length).to eq(1)
      expect(result.data[:entries].first[:message]).to include("timeout")
    end

    it "limits the number of results" do
      result = tool.call(service: "checkout", limit: 2)

      expect(result.success?).to be true
      expect(result.data[:entries].length).to eq(2)
    end

    it "defaults limit to 100" do
      result = tool.call(service: "checkout")

      # Just verify it doesn't fail, actual default applied
      expect(result.success?).to be true
    end

    it "returns entries sorted by timestamp descending (most recent first)" do
      result = tool.call(service: "checkout")

      timestamps = result.data[:entries].map { |e| e[:timestamp] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it "includes count in the response" do
      result = tool.call(service: "checkout")

      expect(result.data[:count]).to eq(result.data[:entries].length)
      expect(result.data[:total_available]).to be_a(Integer)
    end

    it "validates level is a known value" do
      result = tool.call(service: "checkout", level: "invalid")

      expect(result.success?).to be false
      expect(result.errors).to include(/level/)
    end
  end
end
