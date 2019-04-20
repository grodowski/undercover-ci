class AddAnnotationsAndBaseShaToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    add_column :coverage_checks, :annotations, :jsonb
    add_column :coverage_checks, :base_sha, :string
    rename_column :coverage_checks, :head_sha, :head_sha
  end
end
