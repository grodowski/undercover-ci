# frozen_string_literal: true

ruby "3.3.0"
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "rails", "~> 6.1"

gem "aws-sdk-s3", require: false
gem "bcrypt", "~> 3.1.15"
gem "bootsnap", ">= 1.1.0", require: false
gem "jbuilder", "~> 2.12"
gem "kaminari"
gem "pg", ">= 0.18", "< 2.0"
gem "puma"
gem "redis-client"
gem "sidekiq"

# Required for Ruby 3.1+ until the mail gem gets an update
gem "net-imap", require: false
gem "net-pop", require: false
gem "net-smtp", require: false

# UI Gems
gem "bootstrap"
gem "bootstrap5-kaminari-views"
gem "coffee-rails", "~> 5.0"
gem "jquery-rails"
gem "sass-rails"
gem "sprockets"
gem "turbolinks"

# Core
gem "undercover", github: "grodowski/undercover", branch: "handle-grafted-commits"

# Github
gem "jwt"
gem "octokit"

# Auth
gem "omniauth"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"

# Tooling
gem "sentry-rails"
gem "sentry-ruby"

group :development, :test do
  gem "byebug", platforms: %i[mri mingw x64_mingw]
  gem "pry-rails"
  gem "rubocop"
  gem "webmock"
end

group :development do
  gem "listen"
  gem "spring"
  gem "spring-watcher-listen", "~> 2.1.0"
  gem "web-console", ">= 3.3.0"
end

group :test do
  gem "capybara", ">= 2.15"
  gem "rspec-rails"
  gem "selenium-webdriver"
  gem "simplecov"
  gem "simplecov-html"
  gem "simplecov-lcov"
  gem "timecop"
  gem "webdrivers"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
