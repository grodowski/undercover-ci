# frozen_string_literal: true

# Run sidekiq admin UI locally against a known redis instance
#
# Usage:
# set REDIS_URL
# run with puma -p 3001 sidekiq_admin.ru

require "sidekiq"

Sidekiq.configure_client do |config|
  config.redis = {url: ENV.fetch("REDIS_URL")}
end

require "sidekiq/web"
run Sidekiq::Web
