# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.sidekiq.report_after_job_retries = true
end
