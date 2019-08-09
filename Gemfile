# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "rails", "~> 5.2.1"

gem "bcrypt", "~> 3.1.13"
gem "bootsnap", ">= 1.1.0", require: false
gem "jbuilder", "~> 2.9"
gem "pg", ">= 0.18", "< 2.0"
gem "puma", "~> 4.1"

# UI Gems
gem "bootstrap", "~> 4.3.1"
gem "coffee-rails", "~> 5.0"
gem "jquery-rails"
gem "sass-rails", "~> 5.0"
gem "turbolinks", "~> 5"
gem "uglifier", ">= 1.3.0"

# Core
gem "undercover"

# Github
gem "jwt"
gem "octokit"

# Tooling
gem "sentry-raven"

group :development, :test do
  gem "byebug", platforms: %i[mri mingw x64_mingw]
  gem "pry-rails"
  gem "rubocop"
  gem "webmock"
end

group :development do
  gem "listen", ">= 3.0.5", "< 3.2"
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
  gem "web-console", ">= 3.3.0"
end

group :test do
  gem "capybara", ">= 2.15"
  gem "rspec-rails"
  gem "selenium-webdriver"
  gem "simplecov"
  gem "simplecov-html"
  gem "simplecov-lcov"
  gem "webdrivers"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
