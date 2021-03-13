# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id

    redirect_to session.delete(:redirect_post_sign_in_path) || dashboard_url
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url
  end
end
