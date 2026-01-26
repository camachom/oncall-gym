# frozen_string_literal: true

# PHASE 2: Tool System - Base Tool
#
# Tools are the actions an agent can take to investigate an incident.
# The Base class defines the interface all tools must implement.
#
# GUIDELINES:
# - Each tool has a name, description, and parameter schema
# - Tools validate their inputs before execution
# - Tools return structured results (not raw strings)
# - Tools are stateless - they don't maintain state between calls
#
# HINTS:
# - Use dry-validation for parameter schemas
# - Consider what a tool result needs: success/failure, data, errors
# - Think about how to make tools testable (dependency injection)

require "spec_helper"

RSpec.describe OncallGym::Tools::Base do
  # Create a concrete test tool for testing the base class
  let(:test_tool_class) do
    Class.new(described_class) do
      def self.tool_name
        "test_tool"
      end

      def self.description
        "A tool for testing"
      end

      def self.parameter_schema
        {
          required: [:query],
          optional: [:limit],
          types: {
            query: String,
            limit: Integer
          },
          defaults: {
            limit: 10
          }
        }
      end

      def execute(params)
        { results: ["result for #{params[:query]}"], count: params[:limit] }
      end
    end
  end

  describe "class interface" do
    it "requires subclasses to define tool_name" do
      expect(test_tool_class.tool_name).to eq("test_tool")
    end

    it "requires subclasses to define description" do
      expect(test_tool_class.description).to eq("A tool for testing")
    end

    it "requires subclasses to define parameter_schema" do
      schema = test_tool_class.parameter_schema
      expect(schema[:required]).to include(:query)
    end
  end

  describe "#call" do
    let(:tool) { test_tool_class.new }

    it "returns a successful result with valid params" do
      result = tool.call(query: "test query")

      expect(result.success?).to be true
      expect(result.data[:results]).to eq(["result for test query"])
    end

    it "applies default values for optional params" do
      result = tool.call(query: "test")

      expect(result.data[:count]).to eq(10)
    end

    it "accepts explicit values for optional params" do
      result = tool.call(query: "test", limit: 50)

      expect(result.data[:count]).to eq(50)
    end

    it "returns a failure result when required params are missing" do
      result = tool.call({})

      expect(result.success?).to be false
      expect(result.errors).to include(/query/)
    end

    it "returns a failure result when params have wrong type" do
      result = tool.call(query: 123) # Should be String

      expect(result.success?).to be false
      expect(result.errors).to include(/query/)
    end

    it "records execution time" do
      result = tool.call(query: "test")

      expect(result.execution_time_ms).to be >= 0
    end

    it "includes the tool name in the result" do
      result = tool.call(query: "test")

      expect(result.tool_name).to eq("test_tool")
    end
  end

  describe "error handling" do
    let(:failing_tool_class) do
      Class.new(described_class) do
        def self.tool_name = "failing_tool"
        def self.description = "A tool that fails"
        def self.parameter_schema = { required: [], optional: [], types: {}, defaults: {} }

        def execute(_params)
          raise StandardError, "Something went wrong"
        end
      end
    end

    it "catches exceptions and returns failure result" do
      tool = failing_tool_class.new
      result = tool.call({})

      expect(result.success?).to be false
      expect(result.errors).to include(/Something went wrong/)
    end
  end
end

RSpec.describe OncallGym::Tools::Result do
  describe ".success" do
    it "creates a successful result" do
      result = described_class.success(
        tool_name: "logs",
        data: { entries: [] },
        execution_time_ms: 42
      )

      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.tool_name).to eq("logs")
      expect(result.data).to eq({ entries: [] })
      expect(result.execution_time_ms).to eq(42)
      expect(result.errors).to eq([])
    end
  end

  describe ".failure" do
    it "creates a failed result" do
      result = described_class.failure(
        tool_name: "logs",
        errors: ["Invalid service name", "Missing time range"]
      )

      expect(result.success?).to be false
      expect(result.failure?).to be true
      expect(result.errors).to eq(["Invalid service name", "Missing time range"])
      expect(result.data).to be_nil
    end
  end

  describe "#to_h" do
    it "serializes the result" do
      result = described_class.success(
        tool_name: "logs",
        data: { count: 5 },
        execution_time_ms: 100
      )

      hash = result.to_h

      expect(hash[:success]).to be true
      expect(hash[:tool_name]).to eq("logs")
      expect(hash[:data]).to eq({ count: 5 })
      expect(hash[:execution_time_ms]).to eq(100)
    end
  end
end
