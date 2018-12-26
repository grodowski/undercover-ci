# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :v1 do
    post "/hooks", to: "github_webhooks#create"
  end

  root to: "home#index"
  # TODO: comment out pages once they are ready
  # get '/pricing', to: 'home#pricing', as: :pricing_page
end
