# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  class Throttled < StandardError; end

  include ClassLoggable

  queue_as :runner

  # defaults to 3s wait, 2 attempts
  retry_on ActiveStorage::FileNotFoundError,
           Logic::RunUndercover::RunError,
           Logic::RunUndercover::CloneError,
           Octokit::Error,
           Rugged::OSError,
           Faraday::Error,
           Git::FailedError

  retry_on RunnerJob::Throttled,
           wait: ->(executions) { calculate_wait_time(executions - 1) },
           attempts: ENV.fetch("DEFAULT_THROTTLED_RETRY_ATTEMPTS", 120).to_i

  def self.calculate_wait_time(attempt)
    # Fast retries in first few minutes: 5s, 10s, 15s, 20s, 25s, 30s, then 30s
    case attempt
    when 0..5
      (attempt + 1) * 5
    else
      30
    end
  end

  def perform(coverage_check_id)
    @coverage_check = CoverageCheck.find(coverage_check_id)
    @installation = @coverage_check.installation

    raise RunnerJob::Throttled unless can_schedule?

    Logic::RunUndercover.call(@coverage_check)
  end

  private

  def can_schedule?
    count = CoverageCheck.in_progress_for_installation(@installation).count
    count < @coverage_check.max_concurrent_checks
  end
end
