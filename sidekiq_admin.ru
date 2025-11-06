# frozen_string_literal: true

# Run sidekiq admin UI locally against a known redis instance
#
# Usage:
# set REDIS_URL
# run with puma -p 3001 sidekiq_admin.ru

require "rack/session"
require "sidekiq"

Sidekiq.configure_client do |config|
  config.redis = {url: ENV.fetch("REDIS_URL"), ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}}
end

require "sidekiq/web"
use Rack::Session::Cookie, secret: File.read(".session.key"), same_site: true, max_age: 86_400
run Sidekiq::Web
