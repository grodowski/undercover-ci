# frozen_string_literal: true

require "simplecov"
require "undercover/simplecov_formatter"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
  # Seed global randomisation in specs using the rspec seed
  Kernel.srand config.seed

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::Undercover,
      SimpleCov::Formatter::HTMLFormatter
    ]
  )
  SimpleCov.start do
    add_filter(/^\/spec\//)
    enable_coverage(:branch)
  end
end
