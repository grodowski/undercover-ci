# frozen_string_literal: true

class AddPullRequestHeadRefToCoverageChecks < ActiveRecord::Migration[7.2]
  def change
    add_column :coverage_checks, :pull_request_head_ref, :string
  end
end
