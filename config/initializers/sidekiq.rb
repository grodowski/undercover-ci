# frozen_string_literal: true

REDIS_SSL_PARAMS = {ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}}.freeze

Sidekiq.configure_client do |config|
  config.redis = REDIS_SSL_PARAMS.merge(size: 1)
end

Sidekiq.configure_server do |config|
  config.redis = REDIS_SSL_PARAMS
end

# runner jobs are time consuming, always leave an extra slot in the sidekiq concurrency pool
SIDEKIQ_CONCURRENCY = ENV.fetch("SIDEKIQ_CONCURRENCY", 4).to_i
Sidekiq::Queue["runner"].limit = SIDEKIQ_CONCURRENCY - 1
