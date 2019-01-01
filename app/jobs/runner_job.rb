# frozen_string_literal: true

require "check_runs"

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  queue_as :default

  SLEEP = !Rails.env.test?

  # FIXME: mock implementation
  def perform(run)
    run = Hooks::CheckRunInfo.build_from_hash(run)

    Rails.logger.info "Waiting for webhook... #{run}"

    sleep 15 if SLEEP
    # FIXME: needs more states to retry if GitHub api fails
    # FIXME: improve logging `run`
    Rails.logger.info "Starting analysis... #{run}"
    CheckRuns::Run.new run

    sleep 15 if SLEEP
    # FIXME: needs more states to retry if GitHub api fails
    Rails.logger.info "Completing analysis... #{run}"
    CheckRuns::Complete.new run
  end
end
