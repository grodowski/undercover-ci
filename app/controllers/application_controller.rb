# frozen_string_literal: true

class ApplicationController < ActionController::Base
  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def check_current_user
    redirect_to root_url if current_user.nil?
  end

  def validate_installations
    # TODO: ~wrap with a presenter/lib/request object, add specs
    refresh_user_installations
    @installations = current_user.installations
    redirect_to(new_setting_url) if @installations.none?
  end

  # TODO: refresh user installations should soft-delete unistalled installations
  # TODO: currently they get stuck on the dashboard!
  # TODO: ~add specs
  def refresh_user_installations
    client = Octokit::Client.new(access_token: current_user.token)
    client.auto_paginate = true # TODO: move to bg sync?
    installations = client.find_user_installations.to_h
    installations[:installations].each do |inst|
      repos = client.find_installation_repositories_for_user(inst[:id]).to_h
      user_installation = current_user.installations.find_or_create_by!(installation_id: inst[:id])
      user_installation.update!(
        metadata: inst,
        repos: repos[:repositories]
      )
    end
  end

  def dash_installation_url
    app_name = Rails.env.development? ? "undercoverci-dev" : "undercoverci"
    "https://github.com/apps/#{app_name}/installations/new"
  end
  helper_method :dash_installation_url
end
