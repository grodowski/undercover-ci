# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  include ClassLoggable
  queue_as :default
  retry_on ActiveStorage::FileNotFoundError # defaults to 3s wait, 5 attempts

  # TODO: remove MAX_RETRY logic
  MAX_RETRIES = 3

  def perform(coverage_check_id, attempt = 1)
    coverage_check = CoverageCheck.find(coverage_check_id)

    if coverage_check.coverage_reports.empty? && attempt < MAX_RETRIES
      self.class.set(wait: 5.seconds).perform_later(coverage_check_id, attempt + 1)
      return
    end

    Logic::RunUndercover.call(coverage_check)
  end
end
