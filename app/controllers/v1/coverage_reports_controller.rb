# frozen_string_literal: true

require "base64"
require "securerandom"

module V1
  class CoverageReportsController < ApiController # rubocop:disable Metrics/ClassLength
    include JsonFormatterValidation
    include CoverageUploadRateLimit
    include CoverageUploadParams

    protect_from_forgery with: :null_session
    before_action :find_coverage_check
    before_action :check_subscription

    def create
      decoded = Base64.decode64(file_base64)

      input_io = StringIO.new(decoded)
      success = validate_input(input_io)
      if success
        # Undercover::LcovParser closes the io internally 😭
        input_io = StringIO.new(decoded)

        begin
          @coverage_check.transaction do
            attach_report(input_io, file_type)
            Logic::UpdateCoverageCheckState.new(@coverage_check).enqueue
            # Wait 5 seconds to let ActiveStorage process the attachment
            RunnerJob.set(wait: 5.seconds).perform_later(@coverage_check.id)
          end
        rescue Logic::StateTransisionError => _e
          return render_already_uploaded if @coverage_check.state.in?(%i[queued complete])

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

    # Another CI run for the same commit got here first, e.g. a workflow on both push and pull_request
    def render_already_uploaded
      render json: {
        error: "Coverage for #{@coverage_check.head_sha} has already been uploaded to check #{@coverage_check.id}.",
        code: "already_uploaded"
      }, status: :unprocessable_content
    end

    def validate_input(input_io)
      case file_type
      when :lcov
        Undercover::LcovParser.new(input_io, nil).parse
        true
      when :json
        input_io.rewind
        parsed = JSON.parse(input_io.read)
        validate_formatted_json(parsed)
        true
      else
        # simplecov:disable
        false
        # simplecov:enable
      end
    rescue JsonFormatterValidation::Invalid, Undercover::LcovParseError => e
      @error_message = e.message
      false
    rescue JSON::ParserError => e
      @error_message = "Invalid JSON format: #{e.message}"
      false
    end

    def attach_report(input_io, extension)
      hex = SecureRandom.hex(2)
      @coverage_check.coverage_reports.attach(
        io: input_io,
        filename: "#{@coverage_check.id}_#{hex}.#{extension}",
        content_type: content_type
      )
    end

    # :lcov or :json
    def file_type
      params[:file_type]&.to_sym || :lcov
    end

    def content_type
      file_type == :json ? "application/json" : "text/plain"
    end

    def file_base64
      params.require(:file_base64)
    rescue ActionController::ParameterMissing
      params.require(:lcov_base64)
    end

    def find_coverage_check
      repo_full_name, sha = params.require(%i[repo sha])
      pull_request_number = uploaded_pull_request_number
      @coverage_check = Logic::ResolveCoverageCheck.call(
        repo_full_name, sha, pull_request_number,
        base_ref: uploaded_branch(:pull_request_base_ref), head_ref: uploaded_branch(:pull_request_head_ref)
      )
      return if @coverage_check

      render json: not_found_error(repo_full_name, sha), status: :not_found
    end

    # The uploader skips quietly on not_installed, e.g. for a fork's own builds
    def not_found_error(repo_full_name, sha)
      if Installation.where("repos @> ?", [{full_name: repo_full_name}].to_json).exists?
        {error: "No coverage check for #{sha} in #{repo_full_name}"}
      else
        {error: "UndercoverCI is not installed on #{repo_full_name}", code: "not_installed"}
      end
    end

    def check_subscription
      return if @coverage_check.repo_public?
      return if @coverage_check.installation.active?

      @error_message = "Your UndercoverCI license has expired, visit https://undercover-ci.com/settings to subscribe."
      render "shared/generic_error", format: :json, status: :unprocessable_content
    end
  end
end
