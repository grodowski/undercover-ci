# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"
require "rspec/core/rake_task"
require "rubocop/rake_task"

Rails.application.load_tasks

desc "Run RuboCop"
RuboCop::RakeTask.new(:rubocop)

desc "Run Tests"
RSpec::Core::RakeTask.new(:spec)

task default: %i[rubocop spec]
