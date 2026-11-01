# frozen_string_literal: true

require "base64"
require "securerandom"

module V1
  class CoverageReportsController < ApiController
    include JsonFormatterValidation

    UNSUPPORTED_FILE_TYPE = "Unsupported file_type, upload SimpleCov JSON coverage with file_type=json. " \
                            "LCOV is no longer supported, see https://undercover-ci.com/docs#reporting"

    protect_from_forgery with: :null_session
    before_action :find_coverage_check
    before_action :check_subscription

    def create
      decoded = Base64.decode64(file_base64) if json_file_type?

      if decoded && validate_input(decoded)
        @coverage_check.transaction do
          attach_report(StringIO.new(decoded))
          Logic::UpdateCoverageCheckState.new(@coverage_check).enqueue
          # Wait 5 seconds to let ActiveStorage process the attachment
          RunnerJob.set(wait: 5.seconds).perform_later(@coverage_check.id)
        rescue Logic::StateTransisionError => _e
          @error_message = "Coverage check #{@coverage_check.id} has already completed. " \
                           "Please push a new commit to restart."
        end

        if @error_message
          Rails.logger.warn(
            "coverage_controller#create 422 coverage_check:#{@coverage_check.id} error: #{@error_message}"
          )
          render "shared/generic_error", format: :json, status: :unprocessable_content
        else
          head(:created)
        end
      else
        render "shared/generic_error", format: :json, status: :unprocessable_content
      end
    end

    def destroy
      ExpireCheckJob.perform_now(@coverage_check.id, ExpireCheckJob::SKIPPED_MESSAGE)
      head(:no_content)
    end

    private

    def json_file_type?
      return true if params[:file_type] == "json"

      @error_message = UNSUPPORTED_FILE_TYPE
      false
    end

    def validate_input(decoded)
      validate_formatted_json(JSON.parse(decoded))
      true
    rescue JsonFormatterValidation::Invalid => e
      @error_message = e.message
      false
    rescue JSON::ParserError => e
      @error_message = "Invalid JSON format: #{e.message}"
      false
    end

    def attach_report(input_io)
      hex = SecureRandom.hex(2)
      @coverage_check.coverage_reports.attach(
        io: input_io,
        filename: "#{@coverage_check.id}_#{hex}.json",
        content_type: "application/json"
      )
    end

    def file_base64
      params.require(:file_base64)
    end

    def find_coverage_check
      check_params = params.require(%i[repo sha])
      @coverage_check = CoverageCheck.where("repo @> ?", {full_name: check_params.first}.to_json)
                                     .where(head_sha: check_params[1]).first!
    end

    def check_subscription
      return if @coverage_check.repo_public?
      return if @coverage_check.installation.active?

      @error_message = "Your UndercoverCI license has expired, visit https://undercover-ci.com/settings to subscribe."
      render "shared/generic_error", format: :json, status: :unprocessable_content
    end
  end
end
