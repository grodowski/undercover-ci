# frozen_string_literal: true

class GithubWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  WEBHOOK_SECRET = ENV.fetch("GITHUB_WEBHOOK_SECRET")

  EVENT_TYPES = [
    EVENT_TYPE_CHECK_SUITE = "check_suite"
  ].freeze

  # TODO: add webhook event db model?
  def create
    request.body.rewind
    parse_and_validate_webhook(request.body.read)

    process_webhook

    head(:ok)
  end

  private

  def process_webhook
    if @event_type == EVENT_TYPE_CHECK_SUITE
      case @payload["action"].strip
      when /^(re)?requested$/
        File.write("check_suite.json", @payload.to_json)
        CreateCheckRunJob.perform_later(@payload)
        # RunnerJob.perform_later(Time.now.to_i.to_s)
      end
    else
      logger.debug "---- unhandled event"
      logger.debug "---- received #{@payload['action']}/#{@event_type}"
    end
  end

  def parse_and_validate_webhook(payload_raw)
    @event_type = request.headers.fetch("HTTP_X_GITHUB_EVENT")
    begin
      @payload = JSON.parse(payload_raw)
    rescue JSON::ParseError
      @payload = {}
    end
    their_signature_header = request.headers["HTTP_X_HUB_SIGNATURE"] || "sha1="
    method, their_digest = their_signature_header.split("=")
    our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, payload_raw)
    head(:unauthorized) unless their_digest == our_digest
  end
end
