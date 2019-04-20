# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  queue_as :default

  def perform(coverage_check_id)
    # TODO: return if already running
    # TODO: store running state

    coverage_check = CoverageCheck.find(coverage_check_id)
    Logic::RunUndercover.call(coverage_check)
  end
end
