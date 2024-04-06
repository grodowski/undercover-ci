# frozen_string_literal: true

module V1
  class ChecksController < ApiController
    before_action :authenticate_api_token
    before_action :find_coverage_check

    def show
      render(
        json: @coverage_check.as_json(
          only: %i[id head_sha base_sha state state_log],
          methods: :repo_full_name
        ),
        status: :ok
      )
    end

    def download_report
      if Rails.application.config.active_storage.service.in? %i[local test]
        redirect_to url_for(@coverage_check.coverage_reports.last)
      else
        redirect_to @coverage_check.coverage_reports.last.url
      end
    end

    private

    def find_coverage_check
      @coverage_check = current_api_user.coverage_checks.find_by!(head_sha: params[:sha])
    end
  end
end
