# frozen_string_literal: true

class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env["omniauth.auth"])
    session[:user_id] = user.id

    # TODO: create a dashboard layout and redirect
    redirect_to root_url
  end
end
