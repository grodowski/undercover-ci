class AddCheckSuiteToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    add_column :coverage_checks, :check_suite, :jsonb
  end
end
