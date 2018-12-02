# frozen_string_literal: true

# Creates a new check_run. RunnerJob will start once coverage results
# are received by the app
class CreateCheckRunJob < ApplicationJob
  queue_as :default

  PRIVATE_KEY = OpenSSL::PKey::RSA.new(
    ENV.fetch("GITHUB_PRIVATE_KEY").gsub('\n', "\n")
  )
  APP_IDENTIFIER = ENV.fetch("GITHUB_APP_IDENTIFIER")

  # def initialize(_args)
  #   super

  # end

  def perform(webhook_payload)
    @app_client = setup_app_client
    @webhook_payload = webhook_payload
    # TODO: reuse token and store expires_at
    i_token = fetch_installation_token(
      webhook_payload.fetch("installation").fetch("id")
    )
    i_client = Octokit::Client.new(access_token: i_token.token)
    res = i_client.post(
      "/repos/#{repo_name}/check-runs",
      head_sha: head_sha,
      name: "Changeset Coverage",
      status: "completed",
      conclusion: "failure",
      completed_at: Time.now.iso8601,
      external_id: "TODO-ID",
      output: {
        title: "hello, checks!",
        summary: "in progress check",
        text: "**some sample mardown**\n\n```\ndef hello\n  $$$\nend\n```\n~~hello~~",
        annotations: [
          {
            path: 'lib/undercover.rb',
            start_line: 38,
            end_line: 39,
            annotation_level: 'warning',
            title: 'Insufficient Test Coverage',
            message: 'Instance method `test_method` is missing coverage for line 39 (method coverage: 0.0%)'
          }
        ],
      },
      headers: {"Accept": "application/vnd.github.antiope-preview+json"}
    )

    Rails.logger.debug(res.to_h)
  end

  private

  def head_sha
    @webhook_payload.fetch("check_suite").fetch("head_sha")
  end

  def repo_name
    @webhook_payload.fetch("repository").fetch("full_name")
  end

  def fetch_installation_token(installation_id)
    @app_client.create_installation_access_token(
      installation_id,
      headers: {"Accept": "application/vnd.github.antiope-preview+json"}
    )
  end

  def setup_app_client
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60),
      iss: APP_IDENTIFIER
    }
    jwt = JWT.encode(payload, PRIVATE_KEY, "RS256")

    # TODO: Needs an installation token
    Octokit::Client.new(bearer_token: jwt)
  end
end
