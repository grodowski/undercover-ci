# frozen_string_literal: true

require "spec_helper"

require "pry"
require "webmock/rspec"
require "simplecov"
require "simplecov_json_formatter"
require "simplecov-lcov"
require "yaml"

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::LcovFormatter,
    SimpleCov::Formatter::JSONFormatter,
    SimpleCov::Formatter::HTMLFormatter
  ]
)
SimpleCov.start do
  add_filter(/^\/spec\//)
  enable_coverage(:branch)
end

system("source .envrc.example")

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

OmniAuth.config.test_mode = true
OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
  YAML.load_file("spec/fixtures/auth_hash.yaml")
)

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
