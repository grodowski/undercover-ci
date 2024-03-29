# frozen_string_literal: true

module V1
  class ChecksController < ApiController
    before_action :authenticate_api_token
    before_action :find_coverage_check

    def show
      render json: @coverage_check, status: :ok
    end

    def download_report
      redirect_to @coverage_check.coverage_reports.last.url
    end

    private

    def find_coverage_check
      @coverage_check = current_api_user.coverage_checks.find(params[:id])
    end
  end
end
