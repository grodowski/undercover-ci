# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.rails.active_job_report_on_retry_error = true
end
