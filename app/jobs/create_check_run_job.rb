# frozen_string_literal: true

require "check_runs"

# Creates a new check_run when the app receives a check_suite event.
# RunnerJob will start once coverage results are stored.
class CreateCheckRunJob < ApplicationJob
  queue_as :default

  def perform(coverage_check_id)
    coverage_check = CoverageCheck.find(coverage_check_id)
    run = DataObjects::CheckRunInfo.from_coverage_check(coverage_check)

    CheckRuns::Create.new(run).post
  end
end
