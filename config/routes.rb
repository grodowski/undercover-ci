# frozen_string_literal: true

Rails.application.routes.draw do
  API_MIME_TYPES = %w[*/* application/json].freeze
  namespace :v1, constraints: ->(req) { req.format.to_s.in?(API_MIME_TYPES) } do
    post "/hooks", to: "github_webhooks#create"
    post "/coverage", to: "coverage_reports#create"
  end

  root to: "home#index"
  # TODO: comment out pages once they are ready
  # get "/pricing", to: "home#pricing", as: :pricing_page
end
