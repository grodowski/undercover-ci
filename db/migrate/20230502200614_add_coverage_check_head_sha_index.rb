class AddCoverageCheckHeadShaIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :coverage_checks, :head_sha
  end
end
