# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    redirect_to "https://github.com/grodowski/undercover" if Rails.env.production?
  end
end
