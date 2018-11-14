# frozen_string_literal: true

class GithubWebhooksController < ApplicationController
  protect_from_forgery with: :null_session

  PRIVATE_KEY = OpenSSL::PKey::RSA.new(
    ENV.fetch('GITHUB_PRIVATE_KEY').gsub('\n', "\n")
  )
  WEBHOOK_SECRET = ENV.fetch('GITHUB_WEBHOOK_SECRET')
  APP_IDENTIFIER = ENV.fetch('GITHUB_APP_IDENTIFIER')

  # TODO: add webhook event db model?
  def create
    @client = setup_client
    request.body.rewind
    parse_and_validate_webhook(request.body.read)

    logger.debug "---- received event #{@payload['action']}" \
                 " #{request.headers['HTTP_X_GITHUB_EVENT']}"
    logger.debug "---- client: #{@client.inspect}"

    head(:ok)
  end

  private

  def parse_and_validate_webhook(payload_raw)
    begin
      @payload = JSON.parse(payload_raw)
    rescue JSON::ParseError
      @payload = {}
    end
    their_signature_header = request.headers['HTTP_X_HUB_SIGNATURE'] || 'sha1='
    method, their_digest = their_signature_header.split('=')
    our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, payload_raw)
    head(:unauthorized) unless their_digest == our_digest
  end

  def setup_client
    payload = {
      iat: Time.now.to_i,
      exp: Time.now.to_i + (10 * 60),
      iss: APP_IDENTIFIER
    }
    jwt = JWT.encode(payload, PRIVATE_KEY, 'RS256')

    # TODO: May need an installation token in the future
    @client = Octokit::Client.new(bearer_token: jwt)
  end
end
