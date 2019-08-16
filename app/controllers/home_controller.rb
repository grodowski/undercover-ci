# frozen_string_literal: true

class HomeController < ApplicationController
  before_action do
    redirect_to "https://github.com/grodowski/undercover" if Rails.env.production?
  end
end
