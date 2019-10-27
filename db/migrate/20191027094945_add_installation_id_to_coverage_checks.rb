class AddInstallationIdToCoverageChecks < ActiveRecord::Migration[5.2]
  def change
    remove_column :coverage_checks, :installation_id, :string
    add_reference :coverage_checks, :installation, foreign_key: true
  end
end
