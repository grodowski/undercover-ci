# frozen_string_literal: true

module V1
  class GithubWebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    WEBHOOK_SECRET = ENV.fetch("GITHUB_WEBHOOK_SECRET")
    EVENT_TYPES = [
      EVENT_TYPE_CHECK_SUITE = "check_suite",
      EVENT_TYPE_CHECK_RUN = "check_run",
      EVENT_TYPE_INSTALLATION = "installation",
      EVENT_TYPE_INSTALLATION_REPOSITORIES = "installation_repositories"
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
          File.write("check_suite.json", @payload.to_json) unless Rails.env.test?
          # TODO: Start a check run (in_progress)
          run_info = Hooks::CheckRunInfo.from_webhook(@payload)
          CreateCheckRunJob.perform_later(run_info.to_h)

          # FIXME: remove mock, triggers RunnerJob with sleeps inside :o
          RunnerJob.perform_later(run_info.to_h)
        else
          logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        end

      when EVENT_TYPE_CHECK_RUN

        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        case @payload["action"].strip
        when /^(re)?requested$/
          # FIXME: handle check_run re-requests!
          File.write("check_run.json", @payload.to_json) unless Rails.env.test?
        end

      when EVENT_TYPE_INSTALLATION

        # TODO: create an installation record
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        File.write("installation.json", @payload.to_json) unless Rails.env.test?

      when EVENT_TYPE_INSTALLATION_REPOSITORIES

        # TODO: create or soft-delete a repositories
        logger.debug "Webhook Unhandled: #{@payload['action']}/#{@event_type}"
        File.write("installation_repositories.json", @payload.to_json) unless Rails.env.test?

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
