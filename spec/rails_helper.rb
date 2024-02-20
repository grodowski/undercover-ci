# frozen_string_literal: true

require "spec_helper"

require "pry"
require "webmock/rspec"
require "yaml"

system("source .envrc.example")

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

WebMock.disable_net_connect!(allow_localhost: true)

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

  config.before(:each, with_inline_jobs: true) do
    # TODO: remove once https://github.com/rails/rails/issues/37270 is addressed in rails 6.1.next
    RunnerJob.itself # load it
    (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
    @prev_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
  end

  config.after(:each, with_inline_jobs: true) do
    ActiveJob::Base.queue_adapter = @prev_adapter
  end
end
