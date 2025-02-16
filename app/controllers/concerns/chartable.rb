# frozen_string_literal: true

module Chartable
  extend ActiveSupport::Concern

  included do
    private

    def filter_checks_from_params
      date_range = chart_params[:date_range] || "last_30d"
      checks = current_user.coverage_checks.public_send(date_range)
      if chart_params[:repository_name] && chart_params[:repository_name] != "all"
        checks = checks.where("repo->>'full_name' = ?", chart_params[:repository_name])
      end
      if chart_params[:branch_name] && chart_params[:branch_name] != "all"
        checks = checks.where("check_suite->>'head_branch' = ?", chart_params[:branch_name])
      end
      checks = checks.where(result: chart_params[:result]) if chart_params[:result] && chart_params[:result] != "all"
      checks
    end

    def chart_params
      params.permit(:date_range, :repository_name, :branch_name, :result)
    end
  end
end
