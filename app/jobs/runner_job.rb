# frozen_string_literal: true

# RunnerJob assumes that coverage results have been stored. It runs
# the Clone, Analyse and Publish operations in sync.
class RunnerJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info("Running analysis... #{args}")
  end
end
