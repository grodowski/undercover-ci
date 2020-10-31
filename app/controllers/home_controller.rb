# frozen_string_literal: true

class HomeController < ApplicationController
  layout "static_page"

  def beta
    if current_user || params[:x] != ENV.fetch("BETA_CODE")
      redirect_to root_url
      return
    end

    cookies[:beta_sign_in] = {value: 1, expires: 1.year}
  end

  def subscription_confirmation
    redirect_to root_url unless current_user
  end
end
