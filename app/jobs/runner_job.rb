# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  queue_as :default

  SLEEP = !Rails.env.test?

  # FIXME: mock implementation
  def perform(run)
    run = Hooks::CheckRunInfo.new(run)

    Rails.logger.info "Waiting for webhook... #{run}"

    sleep 15 if SLEEP
    # FIXME: needs more states to retry if GitHub api fails
    Rails.logger.info "Starting analysis... #{run}"
    CheckRuns::Run.new run.to_h

    sleep 15 if SLEEP
    # FIXME: needs more states to retry if GitHub api fails
    Rails.logger.info "Completing analysis... #{run}"
    CheckRuns::Complete.new run.to_h
  end
end
