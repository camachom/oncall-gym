# frozen_string_literal: true

# PHASE 2: Tool System - Registry
#
# The Registry manages all available tools and provides lookup by name.
# It's how the workflow engine finds and invokes the right tool.
#
# GUIDELINES:
# - Registry is a singleton or can be instantiated per-scenario
# - Tools are registered by their class
# - Lookup is by string name (what the agent asks for)
# - Should provide introspection (list tools, get schemas)
#
# HINTS:
# - Consider how an agent would discover what tools are available
# - The registry should validate tools on registration
# - Think about permission levels (some tools might be restricted)

require "spec_helper"

RSpec.describe OncallGym::Tools::Registry do
  # Mock tools for testing
  let(:logs_tool_class) do
    Class.new(OncallGym::Tools::Base) do
      def self.tool_name = "logs"
      def self.description = "Search application logs"
      def self.parameter_schema
        { required: [:service], optional: [:level, :limit], types: { service: String, level: String, limit: Integer }, defaults: { limit: 100 } }
      end
      def execute(params) = { entries: [] }
    end
  end

  let(:metrics_tool_class) do
    Class.new(OncallGym::Tools::Base) do
      def self.tool_name = "metrics"
      def self.description = "Query system metrics"
      def self.parameter_schema
        { required: [:service, :metric], optional: [:duration], types: { service: String, metric: String, duration: String }, defaults: { duration: "1h" } }
      end
      def execute(params) = { datapoints: [] }
    end
  end

  describe "#register" do
    it "registers a tool class" do
      registry = described_class.new
      registry.register(logs_tool_class)

      expect(registry.registered?("logs")).to be true
    end

    it "allows registering multiple tools" do
      registry = described_class.new
      registry.register(logs_tool_class)
      registry.register(metrics_tool_class)

      expect(registry.registered?("logs")).to be true
      expect(registry.registered?("metrics")).to be true
    end

    it "raises error if tool_name is not defined" do
      invalid_class = Class.new

      registry = described_class.new
      expect {
        registry.register(invalid_class)
      }.to raise_error(OncallGym::ValidationError, /tool_name/)
    end

    it "raises error if tool is already registered" do
      registry = described_class.new
      registry.register(logs_tool_class)

      expect {
        registry.register(logs_tool_class)
      }.to raise_error(OncallGym::ValidationError, /already registered/)
    end
  end

  describe "#get" do
    it "returns an instance of the registered tool" do
      registry = described_class.new
      registry.register(logs_tool_class)

      tool = registry.get("logs")

      expect(tool).to be_a(logs_tool_class)
    end

    it "raises ToolNotFoundError for unknown tools" do
      registry = described_class.new

      expect {
        registry.get("unknown")
      }.to raise_error(OncallGym::ToolNotFoundError, /unknown/)
    end

    it "returns a new instance each time" do
      registry = described_class.new
      registry.register(logs_tool_class)

      tool1 = registry.get("logs")
      tool2 = registry.get("logs")

      expect(tool1).not_to equal(tool2)
    end
  end

  describe "#tool_names" do
    it "returns list of registered tool names" do
      registry = described_class.new
      registry.register(logs_tool_class)
      registry.register(metrics_tool_class)

      expect(registry.tool_names).to contain_exactly("logs", "metrics")
    end

    it "returns empty array when no tools registered" do
      registry = described_class.new

      expect(registry.tool_names).to eq([])
    end
  end

  describe "#tool_schemas" do
    it "returns schemas for all registered tools" do
      registry = described_class.new
      registry.register(logs_tool_class)
      registry.register(metrics_tool_class)

      schemas = registry.tool_schemas

      expect(schemas.keys).to contain_exactly("logs", "metrics")
      expect(schemas["logs"][:description]).to eq("Search application logs")
      expect(schemas["logs"][:parameters][:required]).to include(:service)
    end
  end

  describe "#call" do
    it "finds and invokes a tool by name" do
      registry = described_class.new
      registry.register(logs_tool_class)

      result = registry.call("logs", service: "checkout")

      expect(result.success?).to be true
      expect(result.tool_name).to eq("logs")
    end

    it "raises ToolNotFoundError for unknown tools" do
      registry = described_class.new

      expect {
        registry.call("unknown", {})
      }.to raise_error(OncallGym::ToolNotFoundError)
    end
  end

  describe ".default" do
    it "returns a registry with standard tools pre-registered" do
      # This test will pass once you implement the standard tools
      # Skip this test initially, uncomment when you have real tools
      skip "Implement after creating LogsTool, MetricsTool, etc."

      registry = described_class.default

      expect(registry.registered?("logs")).to be true
      expect(registry.registered?("metrics")).to be true
      expect(registry.registered?("deploys")).to be true
      expect(registry.registered?("runbook")).to be true
    end
  end
end
