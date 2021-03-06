# frozen_string_literal: true

module Dashboard
  class ChecksController < ApplicationController
    before_action :check_current_user
    before_action :validate_installations

    def index
      # TODO: ~wrap with a presenter/lib/request object, add specs
      @installations = current_user.installations
      redirect_to(new_settings_url) if @installations.none?

      @checks = current_user.coverage_checks.with_counts.order(created_at: :desc).page(params[:page])
      @show_coverage_upload_instruction = @checks.none?
    end

    def show
      @check = current_user.coverage_checks.with_counts.includes(:nodes).find(params[:id])

      @flagged_nodes = @check.nodes.select(&:flagged?)
      @unflagged_nodes = @check.nodes.reject(&:flagged?)
    end
  end
end
