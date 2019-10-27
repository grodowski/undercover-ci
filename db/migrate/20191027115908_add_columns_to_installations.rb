class AddColumnsToInstallations < ActiveRecord::Migration[5.2]
  def change
    add_column :installations, :metadata, :jsonb
    add_column :installations, :repos, :jsonb
  end
end
