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

  def dash_installation_url
    app_name = Rails.env.development? ? "undercoverci-dev" : "undercoverci"
    "https://github.com/apps/#{app_name}/installations/new"
  end
  helper_method :dash_installation_url

  # TODO: refresh user installations should soft-delete unistalled installations
  # TODO: currently they get stuck on the dashboard!
  def refresh_user_installations
    client = Octokit::Client.new(access_token: current_user.token)
    client.auto_paginate = true # TODO: move to bg sync?
    installations = client.find_user_installations.to_h
    installations[:installations].each do |inst|
      repos = client.find_installation_repositories_for_user(inst[:id]).to_h

      # associates with existing installation or creates a new one. Add specs
      installation = Installation.find_by(installation_id: inst[:id])
      if installation
        current_user.installations << installation
      else
        installation = current_user.installations.create!(installation_id: inst[:id])
      end

      # keep installations in sync with GitHub
      installation.update!(metadata: inst, repos: repos[:repositories])
    end
  end
end
