# frozen_string_literal: true

require "check_runs"

# Creates a new check_run when the app receives a check_suite event.
# RunnerJob will start once coverage results are stored.
class CreateCheckRunJob < ApplicationJob
  queue_as :default

  def perform(coverage_report_job_id)
    run = Hooks::CheckRunInfo.from_coverage_report_job(
      CoverageCheck.find(coverage_report_job_id)
    )
    CheckRuns::Create.new(run).post
  end
end
