class CreateCoverageReportJobs < ActiveRecord::Migration[5.2]
  def change
    create_table :coverage_report_jobs do |t|
      t.string :commit_sha
      t.jsonb :repo
      t.text :lcov
      t.jsonb :event_log

      t.timestamps
    end
  end
end
