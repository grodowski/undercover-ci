# frozen_string_literal: true

OmniAuth.config.allowed_request_methods = [:post]

Rails.configuration.middleware.use(OmniAuth::Builder) do
  provider(
    :github, ENV.fetch("GITHUB_AUTH_KEY", nil), ENV.fetch("GITHUB_AUTH_SECRET", nil),
    scope: "user:email", provider_ignores_state: true
  )
end
