# frozen_string_literal: true

require "bundler/setup"
require "rspec/json_expectations"

# Load the library
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "oncall_gym"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random

  Kernel.srand config.seed
end

# Helper to load fixtures
def fixture_path(name)
  File.join(__dir__, "..", "fixtures", name)
end

def load_fixture(name)
  JSON.parse(File.read(fixture_path(name)))
end
