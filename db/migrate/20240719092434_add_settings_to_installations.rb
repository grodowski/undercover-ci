class AddSettingsToInstallations < ActiveRecord::Migration[6.1]
  def change
    add_column :installations, :settings, :jsonb
  end
end
