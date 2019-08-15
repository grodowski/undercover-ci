class AddStateLogToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    add_column :coverage_checks, :state_log, :jsonb
  end
end
