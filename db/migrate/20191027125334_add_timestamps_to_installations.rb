class AddTimestampsToInstallations < ActiveRecord::Migration[5.2]
  def change
    change_table :installations do |t|
      t.timestamps
    end
  end
end
