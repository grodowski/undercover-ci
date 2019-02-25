class AddInstallationIdToCoverageReportJobs < ActiveRecord::Migration[5.2]
  def change
    add_column :coverage_report_jobs, :installation_id, :string
  end
end
