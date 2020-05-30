class MakeInstallationIdUnique < ActiveRecord::Migration[6.0]
  def change
    add_index :installations, [:installation_id], unique: true
  end
end
