# frozen_string_literal: true

class ApplicationController < ActionController::Base
  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def check_current_user
    return if current_user

    session[:redirect_post_sign_in_path] = request.path
    redirect_to root_url
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

  def refresh_user_installations
    client = Octokit::Client.new(access_token: current_user.token)
    client.auto_paginate = true # TODO: move to bg sync?
    installations = client.find_user_installations(
      accept: "application/vnd.github.machine-man-preview+json"
    ).to_h
    installations_to_keep = Set.new
    installations[:installations].each do |inst|
      repos = client.find_installation_repositories_for_user(
        inst[:id],
        accept: "application/vnd.github.machine-man-preview+json"
      ).to_h

      # associates with existing installation or creates a new one. Add specs
      installation = Installation.find_by(installation_id: inst[:id])
      if installation
        current_user.installations << installation unless current_user.installations.include?(installation)
      else
        installation = current_user.installations.create!(installation_id: inst[:id])
      end

      # keep installations in sync with GitHub
      installation.update!(metadata: inst, repos: repos[:repositories])
      installations_to_keep << installation
    end

    # remove user from outstanding installations w/o access
    (current_user.installations - installations_to_keep.to_a).each do |installation_to_remove|
      current_user.user_installations.find_by(installation: installation_to_remove).destroy
    end
  end
end
