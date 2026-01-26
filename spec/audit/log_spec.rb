# frozen_string_literal: true

# PHASE 5: Audit Trail - Log
#
# The Log collects and persists audit events for a run.
# It provides querying and replay capabilities.
#
# GUIDELINES:
# - Logs are append-only (events cannot be modified or deleted)
# - Support filtering by event type, time range, step
# - Enable export for debugging and evaluation
# - Consider different backends (memory, file, database)
#
# HINTS:
# - Think about how you'd debug a failed agent run
# - Logs should support time-travel debugging
# - Consider log retention and cleanup policies

require "spec_helper"

RSpec.describe OncallGym::Audit::Log do
  let(:run_id) { "run-123" }

  describe ".new" do
    it "creates an empty log" do
      log = described_class.new

      expect(log.events).to eq([])
    end

    it "accepts an optional storage backend" do
      backend = double("Backend")
      log = described_class.new(backend: backend)

      expect(log.backend).to eq(backend)
    end
  end

  describe "#append" do
    it "adds an event to the log" do
      log = described_class.new
      event = double("Event", id: "e1", type: :run_started, timestamp: Time.now)

      log.append(event)

      expect(log.events.length).to eq(1)
    end

    it "preserves event order" do
      log = described_class.new
      event1 = double("Event", id: "e1", type: :run_started, timestamp: Time.now)
      event2 = double("Event", id: "e2", type: :step_started, timestamp: Time.now + 1)

      log.append(event1)
      log.append(event2)

      expect(log.events.first.id).to eq("e1")
      expect(log.events.last.id).to eq("e2")
    end

    it "persists to backend if configured" do
      backend = double("Backend")
      expect(backend).to receive(:write)

      log = described_class.new(backend: backend)
      event = double("Event", id: "e1", type: :run_started, timestamp: Time.now, to_h: {})

      log.append(event)
    end
  end

  describe "#events_for_run" do
    it "returns events for a specific run" do
      log = described_class.new
      event1 = double("Event", id: "e1", run_id: "run-1", type: :run_started, timestamp: Time.now)
      event2 = double("Event", id: "e2", run_id: "run-2", type: :run_started, timestamp: Time.now)
      event3 = double("Event", id: "e3", run_id: "run-1", type: :step_started, timestamp: Time.now)

      log.append(event1)
      log.append(event2)
      log.append(event3)

      run1_events = log.events_for_run("run-1")

      expect(run1_events.length).to eq(2)
      expect(run1_events.map(&:id)).to contain_exactly("e1", "e3")
    end
  end

  describe "#events_of_type" do
    it "returns events of a specific type" do
      log = described_class.new
      event1 = double("Event", id: "e1", type: :tool_called, timestamp: Time.now)
      event2 = double("Event", id: "e2", type: :observation_recorded, timestamp: Time.now)
      event3 = double("Event", id: "e3", type: :tool_called, timestamp: Time.now)

      log.append(event1)
      log.append(event2)
      log.append(event3)

      tool_events = log.events_of_type(:tool_called)

      expect(tool_events.length).to eq(2)
    end

    it "accepts multiple types" do
      log = described_class.new
      event1 = double("Event", id: "e1", type: :tool_called, timestamp: Time.now)
      event2 = double("Event", id: "e2", type: :observation_recorded, timestamp: Time.now)
      event3 = double("Event", id: "e3", type: :run_started, timestamp: Time.now)

      log.append(event1)
      log.append(event2)
      log.append(event3)

      events = log.events_of_type(:tool_called, :observation_recorded)

      expect(events.length).to eq(2)
    end
  end

  describe "#events_for_step" do
    it "returns events for a specific step" do
      log = described_class.new
      event1 = double("Event", id: "e1", step_id: "step-1", type: :tool_called, timestamp: Time.now)
      event2 = double("Event", id: "e2", step_id: "step-2", type: :tool_called, timestamp: Time.now)
      event3 = double("Event", id: "e3", step_id: "step-1", type: :observation_recorded, timestamp: Time.now)
      event4 = double("Event", id: "e4", step_id: nil, type: :run_started, timestamp: Time.now)

      log.append(event1)
      log.append(event2)
      log.append(event3)
      log.append(event4)

      step1_events = log.events_for_step("step-1")

      expect(step1_events.length).to eq(2)
    end
  end

  describe "#events_in_range" do
    it "returns events within a time range" do
      log = described_class.new
      base_time = Time.now
      event1 = double("Event", id: "e1", timestamp: base_time)
      event2 = double("Event", id: "e2", timestamp: base_time + 60)
      event3 = double("Event", id: "e3", timestamp: base_time + 120)

      log.append(event1)
      log.append(event2)
      log.append(event3)

      events = log.events_in_range(base_time + 30, base_time + 90)

      expect(events.length).to eq(1)
      expect(events.first.id).to eq("e2")
    end
  end

  describe "#tool_calls" do
    it "returns all tool_called events with their results" do
      log = described_class.new
      call_event = double("Event",
        id: "e1",
        type: :tool_called,
        step_id: "step-1",
        timestamp: Time.now,
        data: { tool_name: "logs", params: { service: "checkout" } }
      )
      result_event = double("Event",
        id: "e2",
        type: :tool_result_received,
        step_id: "step-1",
        timestamp: Time.now + 1,
        data: { success: true, execution_time_ms: 50 }
      )

      log.append(call_event)
      log.append(result_event)

      tool_calls = log.tool_calls

      expect(tool_calls.length).to eq(1)
      expect(tool_calls.first[:call]).to eq(call_event)
      expect(tool_calls.first[:result]).to eq(result_event)
    end
  end

  describe "#timeline" do
    it "returns a human-readable timeline of events" do
      log = described_class.new
      events = [
        double("Event", type: :run_started, timestamp: Time.now, data: { incident_id: "inc-1" }),
        double("Event", type: :step_started, timestamp: Time.now + 1, data: { step_number: 1 }),
        double("Event", type: :tool_called, timestamp: Time.now + 2, data: { tool_name: "logs" })
      ]

      events.each { |e| log.append(e) }

      timeline = log.timeline

      expect(timeline).to be_a(Array)
      expect(timeline.length).to eq(3)
      expect(timeline.first).to include(:time, :description)
    end
  end

  describe "#export" do
    it "exports all events as JSON" do
      log = described_class.new
      event = double("Event",
        id: "e1",
        type: :run_started,
        timestamp: Time.now,
        to_h: { id: "e1", type: :run_started }
      )

      log.append(event)

      json = log.export(:json)

      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed).to be_an(Array)
      expect(parsed.first["id"]).to eq("e1")
    end
  end

  describe "#summary" do
    it "returns summary statistics" do
      log = described_class.new
      [
        double("Event", type: :run_started, run_id: "run-1", timestamp: Time.now),
        double("Event", type: :tool_called, run_id: "run-1", timestamp: Time.now + 1),
        double("Event", type: :tool_called, run_id: "run-1", timestamp: Time.now + 2),
        double("Event", type: :observation_recorded, run_id: "run-1", timestamp: Time.now + 3),
        double("Event", type: :run_completed, run_id: "run-1", timestamp: Time.now + 4)
      ].each { |e| log.append(e) }

      summary = log.summary

      expect(summary[:total_events]).to eq(5)
      expect(summary[:tool_calls]).to eq(2)
      expect(summary[:observations]).to eq(1)
    end
  end

  describe "persistence" do
    describe "FileBackend" do
      it "writes events to a file" do
        # Test with temporary file
        require "tempfile"
        file = Tempfile.new(["audit", ".jsonl"])

        backend = OncallGym::Audit::FileBackend.new(file.path)
        log = described_class.new(backend: backend)

        event = OncallGym::Audit::Event.new(
          type: :run_started,
          run_id: "run-123",
          data: { incident_id: "inc-456" }
        )

        log.append(event)

        # Verify file contains the event
        contents = File.read(file.path)
        expect(contents).to include("run_started")
        expect(contents).to include("run-123")

        file.unlink
      end
    end

    describe "MemoryBackend" do
      it "stores events in memory" do
        backend = OncallGym::Audit::MemoryBackend.new
        log = described_class.new(backend: backend)

        event = double("Event", id: "e1", to_h: { id: "e1" })
        log.append(event)

        expect(backend.stored_events.length).to eq(1)
      end
    end
  end
end
