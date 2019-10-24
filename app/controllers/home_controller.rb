# frozen_string_literal: true

class HomeController < ApplicationController
  layout "static_page"

  before_action do
    redirect_to "https://github.com/grodowski/undercover" unless ENV["FF_MARKETING_PAGE"]
  end
end
