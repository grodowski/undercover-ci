# frozen_string_literal: true

Rails.application.routes.draw do
  API_MIME_TYPES = %w[*/* application/json].freeze
  namespace :v1, constraints: ->(req) { req.format.to_s.in?(API_MIME_TYPES) } do
    post "/hooks", to: "github_webhooks#create"
    post "/coverage", to: "coverage_reports#create"
  end

  get "/auth/github/callback", to: "sessions#create"

  get "/pricing", to: "home#pricing", as: :pricing_page
  get "/privacy", to: "home#privacy", as: :privacy_page
  get "/terms", to: "home#terms", as: :terms_page
  get "/faq", to: "home#faq", as: :faq_page

  root to: "home#index"
end
