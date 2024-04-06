# frozen_string_literal: true

API_MIME_TYPES = %w[*/* application/json].freeze

# rubocop:disable Metrics/BlockLength
Rails.application.routes.draw do
  namespace :v1, constraints: ->(req) { req.format.to_s.in?(API_MIME_TYPES) } do
    post "/hooks", to: "github_webhooks#create"
    post "/coverage", to: "coverage_reports#create"
    post "/sale", to: "gumroad_ping#create"
    get "/checks/:sha", to: "checks#show"
    get "/checks/:sha/coverage", to: "checks#download_report"
  end

  get "/auth/github/callback", to: "sessions#create"
  delete "/auth/logout", to: "sessions#destroy"

  get "/beta", to: "home#beta", as: :beta_page
  get "/pricing", to: "home#pricing", as: :pricing_page
  get "/privacy", to: "home#privacy", as: :privacy_page
  get "/terms", to: "home#terms", as: :terms_page
  get "/faq", to: "home#faq", as: :faq_page
  get "/docs", to: "home#docs", as: :docs_page
  get "/subscription_confirmation", to: "home#subscription_confirmation"

  scope module: "dashboard" do
    get "/app", controller: "checks", action: "index", as: :dashboard
    resources :checks, only: :show

    resources :settings, only: %i[new index] do
      collection do
        post :access_token
      end
    end
  end

  root to: "home#index"
end
# rubocop:enable Metrics/BlockLength
