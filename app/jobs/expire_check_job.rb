# frozen_string_literal: true

class ExpireCheckJob < ApplicationJob
  DEFAULT_WAIT = ENV.fetch("DEFAULT_WAIT", 120.minutes)
  INACTIVE_WAIT = 5.seconds
  SKIPPED_MESSAGE = "Cancelled by user"

  queue_as :default
  retry_on Octokit::Error, Faraday::Error # defaults to 3s wait, 5 attempts

  def perform(coverage_check_id, error_message = "")
    @coverage_check = CoverageCheck.find(coverage_check_id)
    @error_message = error_message
    return if @coverage_check.state.in?(%i[canceled in_progress complete])

    transition_coverage_check
    notify_github_of_timed_out
  end

  private

  def transition_coverage_check
    Logic::UpdateCoverageCheckState.new(@coverage_check).cancel(@error_message)
  end

  def notify_github_of_timed_out
    check_run = DataObjects::CheckRunInfo.from_coverage_check(@coverage_check)
    CheckRuns::Canceled.new(check_run).post
  end
end
