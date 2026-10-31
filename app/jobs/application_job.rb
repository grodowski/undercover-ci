# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  sidekiq_options attempt_threshold: 3
end
