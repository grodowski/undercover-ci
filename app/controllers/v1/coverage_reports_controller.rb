# frozen_string_literal: true

require "base64"
require "securerandom"

module V1
  class CoverageReportsController < ApplicationController
    protect_from_forgery with: :null_session
    before_action :find_coverage_report_job

    def create
      decoded = Base64.decode64(lcov_base64)

      input_io = StringIO.new(decoded)
      success = validate_input(input_io)
      if success
        # Undercover::LcovParser closes the io internally 😭
        input_io = StringIO.new(decoded)

        @coverage_report_job.transaction do
          attach_report(input_io)
          RunnerJob.perform_later(@coverage_report_job.id)
        end

        head(:created)
      else
        render("shared/generic_error.json", status: :unprocessable_entity)
      end
    end

    private

    def validate_input(input_io)
      Undercover::LcovParser.new(input_io).parse
      true
    rescue Undercover::LcovParseError => err
      @error_message = err.message
      false
    end

    def attach_report(input_io)
      hex = SecureRandom.hex(2)
      @coverage_report_job.coverage_reports.attach(
        io: input_io,
        filename: "#{@coverage_report_job.id}_#{hex}.lcov",
        content_type: "text/plain"
      )
    end

    def lcov_base64
      params.require(:lcov_base64)
    end

    def find_coverage_report_job
      crj_params = params.require(%i[repo sha])
      @coverage_report_job = CoverageCheck.where("repo @> ?", {full_name: crj_params[0]}.to_json)
                                              .where(commit_sha: crj_params[1]).first!
    end
  end
end
