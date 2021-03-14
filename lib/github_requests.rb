# frozen_string_literal: true

module GithubRequests
  PRIVATE_KEY = OpenSSL::PKey::RSA.new(
    ENV.fetch("GITHUB_PRIVATE_KEY").gsub('\n', "\n")
  )
  APP_IDENTIFIER = ENV.fetch("GITHUB_APP_IDENTIFIER")

  def installation_token(installation_id)
    app_api_client unless @github_app_client
    i_token = @github_app_client.create_installation_access_token(
      installation_id,
      accept: "application/vnd.github.machine-man-preview+json"
    )
    i_token.token
  end

  def installation_api_client(installation_id)
    Octokit::Client.new(
      access_token: installation_token(installation_id)
    )
  end

  def app_api_client
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60),
      iss: APP_IDENTIFIER
    }
    jwt = JWT.encode(payload, PRIVATE_KEY, "RS256")
    @github_app_client = Octokit::Client.new(bearer_token: jwt)
  end
end
