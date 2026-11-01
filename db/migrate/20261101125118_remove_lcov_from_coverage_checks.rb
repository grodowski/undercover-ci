# frozen_string_literal: true

class RemoveLcovFromCoverageChecks < ActiveRecord::Migration[8.1]
  def change
    remove_column :coverage_checks, :lcov, :text
  end
end
