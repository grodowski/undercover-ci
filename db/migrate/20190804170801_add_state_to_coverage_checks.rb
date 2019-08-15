class AddStateToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    add_column :coverage_checks, :state, :string, index: true
  end
end
