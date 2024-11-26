# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  class Throttled < StandardError; end

  include ClassLoggable
  queue_as :runner

  # default retry for uncaught exceptions
  sidekiq_options retry: 2

  # defaults to 3s wait, 2 attempts
  retry_on ActiveStorage::FileNotFoundError,
           Logic::RunUndercover::RunError,
           Octokit::Error,
           Rugged::OSError

  retry_on RunnerJob::Throttled,
           wait: :polynomially_longer,
           attempts: ENV.fetch("DEFAULT_THROTTLED_RETRY_ATTEMPTS", 20).to_i

  def perform(coverage_check_id)
    @coverage_check = CoverageCheck.find(coverage_check_id)
    @installation = @coverage_check.installation

    raise RunnerJob::Throttled unless can_schedule?

    Logic::RunUndercover.call(@coverage_check)
    log("coverage_check #{coverage_check_id}: #{GC.stat}")
    GC.start
  end

  private

  def can_schedule?
    count = CoverageCheck.in_progress_for_installation(@installation).count
    count < @coverage_check.max_concurrent_checks
  end
end
