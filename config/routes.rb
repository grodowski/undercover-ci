# frozen_string_literal: true

Rails.application.routes.draw do
  post '/hooks', to: 'github_webhooks#create'

  root to: 'home#index'
  # TODO: comment out pages once they are ready
  # get '/pricing', to: 'home#pricing', as: :pricing_page
end
