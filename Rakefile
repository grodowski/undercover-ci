# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

if Rails.env.development? || Rails.env.test?
  require "rubocop/rake_task"
  require "rspec/core/rake_task"

  desc "Run RuboCop"
  RuboCop::RakeTask.new(:rubocop)

  desc "Run Tests"
  RSpec::Core::RakeTask.new(:spec)

  task default: %i[rubocop spec]
end

Rails.application.load_tasks
