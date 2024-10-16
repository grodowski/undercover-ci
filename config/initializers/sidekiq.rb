# frozen_string_literal: true

REDIS_SSL_PARAMS = {ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}}.freeze

Sidekiq.configure_client do |config|
  config.redis = REDIS_SSL_PARAMS.merge(size: 1)
end

Sidekiq.configure_server do |config|
  config.redis = REDIS_SSL_PARAMS.merge(size: 10)
end
