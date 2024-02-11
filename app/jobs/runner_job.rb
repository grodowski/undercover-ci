# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  include ClassLoggable
  queue_as :default

  # default retry for uncaught exceptions
  sidekiq_options retry: 2

  # defaults to 3s wait, 2 attempts
  retry_on ActiveStorage::FileNotFoundError,
           Logic::RunUndercover::RunError,
           Octokit::Error,
           Rugged::ReferenceError

  def perform(coverage_check_id)
    coverage_check = CoverageCheck.find(coverage_check_id)

    Logic::RunUndercover.call(coverage_check)
    log("coverage_check #{coverage_check_id}: #{GC.stat}")
    GC.start
  end
end
