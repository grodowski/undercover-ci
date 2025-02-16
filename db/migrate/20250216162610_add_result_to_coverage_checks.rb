class AddResultToCoverageChecks < ActiveRecord::Migration[7.2]
  def change
    add_column :coverage_checks, :result, :string
    add_index :coverage_checks, :result
  end
end
