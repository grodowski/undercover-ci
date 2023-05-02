class AddCoverageChecksRepoGinIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :coverage_checks, "(repo->'full_name')", using: :gin, name: 'index_coverage_checks_on_repo_name'
  end
end
