# frozen_string_literal: true

module V1
  class GithubWebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    WEBHOOK_SECRET = ENV.fetch("GITHUB_WEBHOOK_SECRET")
    EVENT_TYPES = [
      EVENT_TYPE_CHECK_SUITE = "check_suite", # DONE
      EVENT_TYPE_CHECK_RUN = "check_run", # TODO
      EVENT_TYPE_INSTALLATION = "installation", # TODO
      EVENT_TYPE_INSTALLATION_REPOSITORIES = "installation_repositories" # TODO
    ].freeze

    before_action do
      request.body.rewind
      parse_and_validate_webhook(request.body.read)
    end

    def create
      @event_type = request.headers.fetch("HTTP_X_GITHUB_EVENT")
      process_webhook
      head(:ok)
    end

    private

    def process_webhook
      case @event_type
      when EVENT_TYPE_CHECK_SUITE

        case @payload["action"].strip
        when /^(re)?requested$/
          File.write("check_suite.json", @payload.to_json) if Rails.env.development?

          # TODO: Queue a check run instance (queued)
          # What if already running?
          run_info = DataObjects::CheckRunInfo.from_webhook(@payload)
          Logic::StartCheckRun.call(run_info)
        else
          logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        end

      when EVENT_TYPE_CHECK_RUN

        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        case @payload["action"].strip
        when /^(re)?requested$/
          # FIXME: handle check_run re-requests!
          File.write("check_run.json", @payload.to_json) if Rails.env.development?
        end

      when EVENT_TYPE_INSTALLATION

        # TODO: create an installation record
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        File.write("installation.json", @payload.to_json) if Rails.env.development?

      when EVENT_TYPE_INSTALLATION_REPOSITORIES

        # TODO: create or soft-delete a repositories
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        File.write("installation_repositories.json", @payload.to_json) if Rails.env.development?

      else
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
      end
    end

    ALLOWED_DIGEST = %w[sha sha1 sha224 sha256 sha384 sha512].freeze

    def parse_and_validate_webhook(payload_raw)
      begin
        @payload = JSON.parse(payload_raw)
      rescue JSON::ParseError
        @payload = {}
      end
      their_signature_header = request.headers["HTTP_X_HUB_SIGNATURE"] || "sha1="
      method, their_digest = their_signature_header.split("=")
      head(:unauthorized) && return unless method.in?(ALLOWED_DIGEST)
      our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, payload_raw)
      head(:unauthorized) unless their_digest == our_digest
    end
  end
end
