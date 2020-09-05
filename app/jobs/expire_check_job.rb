# frozen_string_literal: true

class ExpireCheckJob < ApplicationJob
  DEFAULT_WAIT = 90.minutes
  queue_as :default
  retry_on Octokit::Error # defaults to 3s wait, 5 attempts

  def perform(coverage_check_id)
    @coverage_check = CoverageCheck.find(coverage_check_id)
    notify_github_of_timed_out
    transition_coverage_check
  end

  private

  def transition_coverage_check
    Logic::UpdateCoverageCheckState.new(@coverage_check).expire
  end

  def notify_github_of_timed_out
    check_run = DataObjects::CheckRunInfo.from_coverage_check(@coverage_check)
    CheckRuns::TimedOut.new(check_run).post
  end
end
