class RenameCoverageReportJobsToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    rename_table :coverage_report_jobs, :coverage_checks
  end
end
