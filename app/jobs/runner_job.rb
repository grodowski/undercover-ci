# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  include ClassLoggable
  queue_as :default
  retry_on Octokit::Error, ActiveStorage::FileNotFoundError # defaults to 3s wait, 5 attempts

  def perform(coverage_check_id)
    coverage_check = CoverageCheck.find(coverage_check_id)

    Logic::RunUndercover.call(coverage_check)
  end
end
