# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :check_current_user

  def dash_installation_url
    app_name = Rails.env.development? ? "undercoverci-dev" : "undercoverci"
    "https://github.com/apps/#{app_name}/installations/new"
  end
  helper_method :dash_installation_url
end
