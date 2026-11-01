# frozen_string_literal: true

class AddPullRequestNumberToCoverageChecks < ActiveRecord::Migration[7.2]
  def change
    add_column :coverage_checks, :pull_request_number, :integer
  end
end
