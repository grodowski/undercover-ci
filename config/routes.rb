# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'home#index'
  # TODO: comment out pages once they are ready
  # get '/pricing', to: 'home#pricing', as: :pricing_page
end
