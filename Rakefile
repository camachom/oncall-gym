# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc "Run linter and auto-fix issues"
task :lint do
  sh "bundle exec rubocop -a"
end

namespace :spec do
  desc "Run Phase 1 tests (Incidents)"
  RSpec::Core::RakeTask.new(:phase1) do |t|
    t.pattern = "spec/incidents/**/*_spec.rb"
  end

  desc "Run Phase 2 tests (Tools)"
  RSpec::Core::RakeTask.new(:phase2) do |t|
    t.pattern = "spec/tools/**/*_spec.rb"
  end

  desc "Run Phase 3 tests (Workflows)"
  RSpec::Core::RakeTask.new(:phase3) do |t|
    t.pattern = "spec/workflows/**/*_spec.rb"
  end

  desc "Run Phase 4 tests (Simulator)"
  RSpec::Core::RakeTask.new(:phase4) do |t|
    t.pattern = "spec/simulator/**/*_spec.rb"
  end

  desc "Run Phase 5 tests (Audit)"
  RSpec::Core::RakeTask.new(:phase5) do |t|
    t.pattern = "spec/audit/**/*_spec.rb"
  end

  desc "Run integration tests"
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = "spec/integration/**/*_spec.rb"
    ENV["RUN_INTEGRATION"] = "1"
  end
end

task default: :spec
