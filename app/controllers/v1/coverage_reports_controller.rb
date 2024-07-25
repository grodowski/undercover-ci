# frozen_string_literal: true

require "base64"
require "securerandom"

module V1
  class CoverageReportsController < ApiController
    protect_from_forgery with: :null_session
    before_action :find_coverage_check
    before_action :check_subscription

    def create
      decoded = Base64.decode64(lcov_base64)

      input_io = StringIO.new(decoded)
      success = validate_input(input_io)
      if success
        # Undercover::LcovParser closes the io internally 😭
        input_io = StringIO.new(decoded)

        @coverage_check.transaction do
          attach_report(input_io)
          Logic::UpdateCoverageCheckState.new(@coverage_check).start
          # Wait 5 seconds to let ActiveStorage process the attachment
          RunnerJob.set(wait: 5.seconds).perform_later(@coverage_check.id)
        rescue Logic::StateTransisionError => _e
          @error_message = "Coverage check #{@coverage_check.id} has already completed. " \
                           "Please push a new commit to restart."
        end

        if @error_message
          render "shared/generic_error", format: :json, status: :unprocessable_entity
        else
          head(:created)
        end
      else
        render "shared/generic_error", format: :json, status: :unprocessable_entity
      end
    end

    def destroy
      ExpireCheckJob.perform_now(@coverage_check.id, ExpireCheckJob::SKIPPED_MESSAGE)
      head(:no_content)
    end

    private

    def validate_input(input_io)
      Undercover::LcovParser.new(input_io).parse
      true
    rescue Undercover::LcovParseError => e
      @error_message = e.message
      false
    end

    def attach_report(input_io)
      hex = SecureRandom.hex(2)
      @coverage_check.coverage_reports.attach(
        io: input_io,
        filename: "#{@coverage_check.id}_#{hex}.lcov",
        content_type: "text/plain"
      )
    end

    def lcov_base64
      params.require(:lcov_base64)
    end

    def find_coverage_check
      check_params = params.require(%i[repo sha])
      @coverage_check = CoverageCheck.where("repo @> ?", {full_name: check_params[0]}.to_json)
                                     .where(head_sha: check_params[1]).first!
    end

    def check_subscription
      return if @coverage_check.repo_public?
      return if @coverage_check.installation.active?

      @error_message = "Your UndercoverCI license has expired, visit https://undercover-ci.com/settings to subscribe."
      render "shared/generic_error", format: :json, status: :unprocessable_entity
    end
  end
end
