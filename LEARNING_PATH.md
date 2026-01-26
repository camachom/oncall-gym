# Oncall Gym - Learning Path

A test-driven learning project for building an incident-response agent simulator.

## How This Works

This project uses **test-driven learning**: tests are provided, and you implement the code to make them pass. Each phase builds on the previous one, gradually constructing a complete incident response simulation system.

## Getting Started

```bash
# Install dependencies
bundle install

# Run tests for a specific phase
bundle exec rspec spec/incidents/    # Phase 1
bundle exec rspec spec/tools/        # Phase 2
bundle exec rspec spec/workflows/    # Phase 3
bundle exec rspec spec/simulator/    # Phase 4
bundle exec rspec spec/audit/        # Phase 5

# Run all tests (once everything is implemented)
bundle exec rspec
```

## Project Structure

```
oncall-gym/
├── lib/
│   └── oncall_gym/
│       ├── incidents/       # Phase 1: Core domain models
│       ├── tools/           # Phase 2: Diagnostic tools
│       ├── workflows/       # Phase 3: Agent execution engine
│       ├── simulator/       # Phase 4: Simulated environment
│       └── audit/           # Phase 5: Event logging
├── spec/                    # Test files (your guide!)
├── fixtures/                # Sample incident data
└── LEARNING_PATH.md         # This file
```

---

## Phase 1: Core Domain Models

**Goal:** Define the fundamental data structures for incidents and agent reasoning.

**Files to create:**
- `lib/oncall_gym/incidents/incident.rb`
- `lib/oncall_gym/incidents/observation.rb`
- `lib/oncall_gym/incidents/hypothesis.rb`

**Tests:** `spec/incidents/`

### Key Concepts

**Incident**: The triggering alert that starts an investigation.
- Has: service, description, severity, tags
- Immutable value object
- Auto-generates ID if not provided

**Observation**: What the agent learned from a diagnostic action.
- Links to a tool invocation
- Contains summary and optional raw data
- Marks whether it was "significant"

**Hypothesis**: The agent's current theory about what's wrong.
- Has confidence level (0.0 - 1.0)
- References supporting observations
- May include proposed mitigation
- Status: investigating → supported/refuted → actionable

### Implementation Tips

```ruby
# Consider using plain Ruby with attr_reader for immutability:
class Incident
  attr_reader :id, :service, :description, :severity, :tags, :created_at

  VALID_SEVERITIES = [:critical, :high, :medium, :low].freeze

  def initialize(service:, description:, id: nil, severity: :high, tags: {}, created_at: nil)
    @id = id || SecureRandom.uuid
    @service = service
    @description = description
    @severity = validate_severity!(severity)
    @tags = tags.freeze
    @created_at = created_at || Time.now
    freeze  # Makes the object immutable
  end

  private

  def validate_severity!(severity)
    raise OncallGym::ValidationError, "Invalid severity" unless VALID_SEVERITIES.include?(severity)
    severity
  end
end
```

### Success Criteria
```bash
bundle exec rspec spec/incidents/ --format documentation
# All tests should pass
```

---

## Phase 2: Tool System

**Goal:** Build the interface for diagnostic tools the agent can use.

**Files to create:**
- `lib/oncall_gym/tools/base.rb`
- `lib/oncall_gym/tools/result.rb`
- `lib/oncall_gym/tools/registry.rb`
- `lib/oncall_gym/tools/logs_tool.rb`
- `lib/oncall_gym/tools/metrics_tool.rb`
- `lib/oncall_gym/tools/deploys_tool.rb`
- `lib/oncall_gym/tools/runbook_tool.rb`

**Tests:** `spec/tools/`

### Key Concepts

**Base Tool**: Abstract class defining the tool interface.
- `call(params)` → validates params, executes, returns Result
- Each tool defines: name, description, parameter schema
- Tools receive a `data_source` for accessing simulated data

**Result**: Structured response from tool execution.
- Success or failure status
- Data payload or error messages
- Execution time tracking

**Registry**: Manages available tools.
- Register tools by class
- Look up tools by name
- Provide schema introspection for agents

### Implementation Tips

```ruby
class OncallGym::Tools::Base
  def call(params)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # Validate parameters
    errors = validate_params(params)
    return Result.failure(tool_name: self.class.tool_name, errors: errors) if errors.any?

    # Apply defaults
    params_with_defaults = apply_defaults(params)

    # Execute
    data = execute(params_with_defaults)

    execution_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

    Result.success(
      tool_name: self.class.tool_name,
      data: data,
      execution_time_ms: execution_time
    )
  rescue StandardError => e
    Result.failure(tool_name: self.class.tool_name, errors: [e.message])
  end

  def execute(params)
    raise NotImplementedError
  end
end
```

### Success Criteria
```bash
bundle exec rspec spec/tools/ --format documentation
```

---

## Phase 3: Workflow Engine

**Goal:** Build the stateful execution engine for agent runs.

**Files to create:**
- `lib/oncall_gym/workflows/step.rb`
- `lib/oncall_gym/workflows/run.rb`
- `lib/oncall_gym/workflows/engine.rb`

**Tests:** `spec/workflows/`

### Key Concepts

**Step**: A single iteration of the agent's decision loop.
- Captures: decision, tool call, result, observation
- Tracks timing and status
- Immutable record for audit trail

**Run**: Complete investigation of an incident.
- Contains incident + all steps + resolution
- Lifecycle: started → running → completed/failed/escalated
- Enforces safety limits (max steps)

**Engine**: Orchestrates the agent execution.
- Takes agent (decision maker) and tool registry
- Executes steps one at a time
- Emits events for audit trail

### The Agent Decision Loop

```
┌─────────────────────────────────────────────────────┐
│                    AGENT RUN                        │
├─────────────────────────────────────────────────────┤
│  1. Agent receives: incident, observations, hypothesis
│  2. Agent decides: call_tool | propose_mitigation | escalate
│  3. If call_tool:
│     a. Engine invokes tool with params
│     b. Engine passes result to agent
│     c. Agent analyzes → observation + hypothesis update
│  4. Repeat until terminal state
└─────────────────────────────────────────────────────┘
```

### Agent Interface

Your engine should accept any object implementing this interface:

```ruby
# Agent must implement:

def decide_next_action(incident:, observations:, current_hypothesis:, step_number:)
  # Returns one of:
  # { action: :call_tool, tool_name: "logs", tool_params: {...}, reasoning: "..." }
  # { action: :propose_mitigation, mitigation: "...", confidence: 0.9, reasoning: "..." }
  # { action: :escalate, reason: "...", escalation_target: "..." }
end

def analyze_result(tool_result:, incident:, current_hypothesis:)
  # Returns:
  # { observation: "...", significant: true/false, hypothesis_update: {...} or nil }
end
```

### Success Criteria
```bash
bundle exec rspec spec/workflows/ --format documentation
```

---

## Phase 4: Simulator

**Goal:** Build the simulated production environment.

**Files to create:**
- `lib/oncall_gym/simulator/data_store.rb`
- `lib/oncall_gym/simulator/scenario.rb`

**Tests:** `spec/simulator/`

### Key Concepts

**DataStore**: Provides access to simulated telemetry.
- Loads from fixture files (JSON)
- Query methods for logs, metrics, deploys, runbooks
- Supports filtering and time ranges

**Scenario**: Complete incident setup with ground truth.
- Bundles incident + fixture data + expected resolution
- Defines success criteria for evaluation
- Supports scoring agent performance

### Fixture Structure

```
fixtures/incidents/latency_spike/
├── scenario.json    # Metadata, incident, ground truth
├── logs.json        # Simulated log entries
├── metrics.json     # Simulated time-series data
├── deploys.json     # Deploy history
└── runbooks.json    # Operational procedures
```

### Evaluation

Scenarios can evaluate agent runs:
- Did it propose correct/acceptable mitigation?
- Did it identify key evidence?
- How many steps did it take (efficiency)?

### Success Criteria
```bash
bundle exec rspec spec/simulator/ --format documentation
```

---

## Phase 5: Audit Trail

**Goal:** Build the event logging system for debugging and evaluation.

**Files to create:**
- `lib/oncall_gym/audit/event.rb`
- `lib/oncall_gym/audit/log.rb`

**Tests:** `spec/audit/`

### Key Concepts

**Event**: Immutable record of an action.
- Types: run_started, step_started, tool_called, observation_recorded, etc.
- Contains all context needed for replay
- Serializable to JSON

**Log**: Collection of events with query capabilities.
- Append-only (events cannot be modified)
- Filter by run, step, type, time range
- Export for debugging and evaluation

### Event Types

```ruby
# Run lifecycle
:run_started, :run_completed, :run_failed, :run_escalated

# Step lifecycle
:step_started, :step_completed, :step_failed

# Agent actions
:decision_made, :tool_called, :tool_result_received

# State changes
:observation_recorded, :hypothesis_created, :hypothesis_updated
```

### Success Criteria
```bash
bundle exec rspec spec/audit/ --format documentation
```

---

## Phase 6: Integration

**Goal:** Verify all components work together.

**Tests:** `spec/integration/`

Run integration tests once all phases are complete:

```bash
RUN_INTEGRATION=1 bundle exec rspec spec/integration/ --format documentation
```

---

## Learning Milestones

### Milestone 1: Data Modeling ✓
After Phase 1, you understand:
- Immutable value objects in Ruby
- Validation patterns
- Building copyable objects with `with_*` methods

### Milestone 2: Tool Abstraction ✓
After Phase 2, you understand:
- Plugin architectures
- Schema validation
- Result types (success/failure)

### Milestone 3: Workflow Orchestration ✓
After Phase 3, you understand:
- State machines
- Event-driven architecture
- Dependency injection (agent, tools)

### Milestone 4: Simulation ✓
After Phase 4, you understand:
- Fixture-based testing
- Evaluation/scoring systems
- Separating simulation from production

### Milestone 5: Observability ✓
After Phase 5, you understand:
- Event sourcing patterns
- Audit logging
- Time-travel debugging

---

## Next Steps

Once all phases pass, you can:

1. **Create more scenarios** - Add incidents with different root causes
2. **Build a real agent** - Integrate with an LLM (Claude, GPT, etc.)
3. **Add persistence** - Use PostgreSQL for storing runs
4. **Build a UI** - Visualize agent decision-making
5. **Add background jobs** - Use Sidekiq for async execution
6. **Build the HTTP API** - Create a Rails API layer

---

## Tips for Success

1. **Read the test file first** - The spec is your specification
2. **Start with the simplest test** - Get one passing, then the next
3. **Use the hints in spec comments** - They guide your implementation
4. **Don't over-engineer** - Match what the tests expect, nothing more
5. **Run tests frequently** - `bundle exec rspec spec/incidents/incident_spec.rb`
6. **Commit after each passing phase** - Track your progress

Good luck, and have fun building your incident response agent simulator!
