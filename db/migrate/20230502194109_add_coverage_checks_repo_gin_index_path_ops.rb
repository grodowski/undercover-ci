class AddCoverageChecksRepoGinIndexPathOps < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    remove_index :coverage_checks, name: :index_coverage_checks_on_repo_name
    add_index :coverage_checks, :repo, using: :gin, opclass: :jsonb_path_ops
  end

  def down
    remove_index :coverage_checks, :repo, using: :gin, opclass: :jsonb_path_ops, algorithm: :concurrently
  end
end
