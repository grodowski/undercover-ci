# frozen_string_literal: true

module Dashboard
  class ChecksController < ApplicationController
    include Chartable
    DEFAULT_PER_PAGE = 25

    before_action :check_current_user
    before_action :validate_installations

    def index
      @installations = current_user.installations
      redirect_to(new_settings_url) if @installations.none?

      @checks = paginate(filter_checks_from_params.with_counts.order(created_at: :desc))
      @repository_names = repo_names_options_for_select
      @branch_names = branch_names_options_for_select
      @show_coverage_upload_instruction = current_user.coverage_checks.none?
    end

    def show
      @check = current_user.coverage_checks.with_counts.includes(:nodes).find(params[:id])

      @flagged_nodes = @check.nodes.select(&:flagged?)
      @unflagged_nodes = @check.nodes.reject(&:flagged?)
    end

    private

    def repo_names_options_for_select
      current_user.installations.map(&:repo_names).flatten.uniq.sort.unshift(["All repositories", "all"])
    end

    def branch_names_options_for_select
      checks = current_user.coverage_checks
      checks = checks.where("repo->>'full_name' = ?", chart_params[:repository_name]) if chart_params[:repository_name]

      checks.last_90d
            .order(created_at: :desc)
            .pluck(Arel.sql("check_suite->>'head_branch'"))
            .uniq.unshift(["All branches", "all"])
    end

    def chart_params_for_async_chart
      chart_params.to_h
    end
    helper_method :chart_params_for_async_chart

    def paginate(collection)
      collection.page(params[:page]).per(DEFAULT_PER_PAGE)
    end
  end
end
