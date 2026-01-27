# frozen_string_literal: true

# Main entry point for Oncall Gym
# Uncomment requires as you implement each module

module OncallGym
  class Error < StandardError; end
  class ValidationError < Error; end
  class ToolNotFoundError < Error; end
  class WorkflowError < Error; end

  # Phase 1: Core Domain
  require_relative "oncall_gym/incidents/incident"
  require_relative "oncall_gym/incidents/observation"
  # require_relative "oncall_gym/incidents/hypothesis"

  # Phase 2: Tools
  # require_relative "oncall_gym/tools/base"
  # require_relative "oncall_gym/tools/registry"
  # require_relative "oncall_gym/tools/logs_tool"
  # require_relative "oncall_gym/tools/metrics_tool"
  # require_relative "oncall_gym/tools/deploys_tool"
  # require_relative "oncall_gym/tools/runbook_tool"

  # Phase 3: Workflows
  # require_relative "oncall_gym/workflows/step"
  # require_relative "oncall_gym/workflows/run"
  # require_relative "oncall_gym/workflows/engine"

  # Phase 4: Simulator
  # require_relative "oncall_gym/simulator/data_store"
  # require_relative "oncall_gym/simulator/scenario"

  # Phase 5: Audit
  # require_relative "oncall_gym/audit/event"
  # require_relative "oncall_gym/audit/log"
end
