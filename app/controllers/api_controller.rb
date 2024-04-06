# frozen_string_literal: true

class ApiController < ActionController::Base
  attr_reader :current_api_user

  helper_method :current_api_user

  private

  def authenticate_api_token
    authenticate_user_with_token || render(json: {message: "Bad credentials"}, status: :unauthorized)
  end

  def authenticate_user_with_token
    authenticate_with_http_token do |token, _options|
      @current_api_user = User.find_by_api_token(token)
    end
  end
end
