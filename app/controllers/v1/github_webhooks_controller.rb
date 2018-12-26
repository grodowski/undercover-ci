# frozen_string_literal: true

module V1
  class GithubWebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    WEBHOOK_SECRET = ENV.fetch("GITHUB_WEBHOOK_SECRET")

    EVENT_TYPES = [
      EVENT_TYPE_CHECK_SUITE = "check_suite",
      EVENT_TYPE_INSTALLATION = "installation",
      EVENT_TYPE_INSTALLATION_REPOSITORIES = "installation_repositories"
    ].freeze

    def create
      request.body.rewind
      parse_and_validate_webhook(request.body.read)

      process_webhook

      head(:ok)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def process_webhook
      case @event_type
      when EVENT_TYPE_CHECK_SUITE
        case @payload["action"].strip
        when /^(re)?requested$/
          File.write("check_suite.json", @payload.to_json)
          # TODO: Start a check run (in_progress)
          # CreateCheckRunJob.perform_later(@payload)
          # TODO: RunnerJob sleeps and auto-completes for now (done)
          # RunnerJob.perform_later(Time.now.to_i.to_s)
        end
      when EVENT_TYPE_INSTALLATION
        # TODO: create an installation record
        File.write("installation.json", @payload.to_json)
      when EVENT_TYPE_INSTALLATION_REPOSITORIES
        # TODO: create/soft-delete a repository
        File.write("installation_repositories.json", @payload.to_json)
      else
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
      end
    end
    # rubocop:enable Metrics/MethodLength

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
end
