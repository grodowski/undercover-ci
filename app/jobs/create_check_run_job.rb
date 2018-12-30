# frozen_string_literal: true

require "check_runs"

# Creates a new check_run when the app receives a check_suite event.
# RunnerJob will start once coverage results are stored.
class CreateCheckRunJob < ApplicationJob
  queue_as :default

  # FIXME: mock implementation
  def perform(webhook_payload)
    CheckRuns::Create.from_check_suite(webhook_payload)
  end
end
