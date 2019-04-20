class RenameCoverageReportJobsToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    rename_table :coverage_checks, :coverage_checks
  end
end
