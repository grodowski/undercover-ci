# frozen_string_literal: true

module Dashboard
  class SettingsController < ApplicationController
    before_action :check_current_user
    before_action :validate_installations, except: :new

    REDIS_SSL_PARAMS = {ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}}.freeze

    def index
      @api_token = fetch_user_displayable_token
      @installations = current_user.installations
    end

    def access_token
      new_token = current_user.reset_api_token
      redis.call("SET", "access_token_#{current_user.id}", new_token, "EX", 30)
      redirect_to settings_path
    end

    def update_branch_filter
      installation = current_user.installations.find_by!(installation_id: params[:installation_id])

      unless params[:repo_full_name].present?
        redirect_to settings_path, alert: "Repository name is required"
        return
      end

      installation.set_repo_branch_filter(params[:repo_full_name], params[:branch_filter_regex])
      redirect_to settings_path, notice: "Branch filter updated for #{params[:repo_full_name]}"
    end

    private

    def fetch_user_displayable_token
      new_token = nil
      redis.with do |r|
        new_token = r.call("GET", "access_token_#{current_user.id}")
        r.call("DEL", "access_token_#{current_user.id}")
      end
      new_token.presence
    end

    def redis
      @redis ||= RedisClient.new(
        REDIS_SSL_PARAMS.merge(url: ENV.fetch("REDIS_URL", "redis://localhost:6379"))
      )
    end
  end
end
