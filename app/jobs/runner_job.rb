# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  queue_as :default

  def perform(coverage_report_job_id)
    # TODO: return if already running
    # TODO: store running state

    coverage_report_job = CoverageCheck.find(coverage_report_job_id)
    Logic::RunUndercover.call(coverage_report_job)
  end
end
