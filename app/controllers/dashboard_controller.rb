# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :check_current_user

  def index
    client = Octokit::Client.new(access_token: current_user.token)
    # TODO: ~save installations to db, associate with user
    # TODO: ~wrap with a presenter / lib/request object
    @installations = client.find_user_installations.to_h
    @repositories = @installations[:installations].each_with_object({}) do |inst, repos|
      repos[inst[:id]] = client.find_installation_repositories_for_user(inst[:id])
    end
  end
end
