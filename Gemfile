# frozen_string_literal: true

ruby "3.4.5"
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "rails", "~> 8.0"

gem "aws-sdk-s3", require: false
gem "bcrypt", "~> 3.1.15"
gem "bootsnap", ">= 1.1.0", require: false
gem "jbuilder", "~> 2.14"
gem "kaminari"
gem "ostruct"
gem "pg", ">= 0.18", "< 2.0"
gem "puma"
gem "redis-client"
gem "sidekiq"
gem "sidekiq-limit_fetch"

# Charts
gem "chartkick"
gem "groupdate"

# Required for Ruby 3.1+ until the mail gem gets an update
gem "net-imap", require: false
gem "net-pop", github: "ruby/net-pop" # https://stackoverflow.com/questions/78617432/strange-bundle-update-issue-disappearing-net-pop-0-1-2-dependency/78620570#78620570
gem "net-protocol", require: false
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
gem "git"
gem "undercover"

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
gem "sentry-sidekiq"

group :development, :test do
  gem "byebug", platforms: %i[mri windows]
  gem "pry-rails"
  gem "rspec-rails"
  gem "rubocop"
  gem "ruby-lsp-rspec", require: false
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
  gem "selenium-webdriver"
  gem "simplecov"
  gem "simplecov-html"
  gem "timecop"
  gem "webdrivers"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]
