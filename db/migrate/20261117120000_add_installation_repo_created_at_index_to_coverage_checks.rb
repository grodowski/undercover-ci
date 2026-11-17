# frozen_string_literal: true

class AddInstallationRepoCreatedAtIndexToCoverageChecks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :coverage_checks, "installation_id, (repo->>'full_name'), created_at",
              name: "index_coverage_checks_on_installation_repo_created_at", algorithm: :concurrently
  end
end
