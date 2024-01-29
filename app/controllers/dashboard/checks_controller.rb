# frozen_string_literal: true

module Dashboard
  class ChecksController < ApplicationController
    before_action :check_current_user
    before_action :validate_installations

    # TODO: add filtering:
    # - repo (select box)
    # - state (passed, failed, all)
    # - date (optional)
    # TODO: add chartkick as an instance variable here
    def index
      # TODO: ~wrap with a presenter/lib/request object, add specs
      @installations = current_user.installations
      redirect_to(new_settings_url) if @installations.none?

      @checks = current_user.coverage_checks.with_counts.order(created_at: :desc).page(params[:page])
      @repository_names = current_user.installations.map(&:repo_names).flatten.uniq.sort.unshift(%w[All all])
      @show_coverage_upload_instruction = current_user.coverage_checks.none?
    end

    def show
      @check = current_user.coverage_checks.with_counts.includes(:nodes).find(params[:id])

      @flagged_nodes = @check.nodes.select(&:flagged?)
      @unflagged_nodes = @check.nodes.reject(&:flagged?)
    end
  end
end
