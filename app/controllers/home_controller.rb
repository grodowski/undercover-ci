# frozen_string_literal: true

class HomeController < ApplicationController
  layout "static_page"

  before_action do
    redirect_to "https://github.com/grodowski/undercover" unless ENV["FF_MARKETING_PAGE"]
  end

  def beta
    if current_user || params[:x] != ENV.fetch("BETA_CODE")
      redirect_to root_url
      return
    end

    cookies[:beta_sign_in] = 1
  end
end
