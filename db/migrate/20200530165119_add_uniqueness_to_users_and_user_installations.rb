class AddUniquenessToUsersAndUserInstallations < ActiveRecord::Migration[6.0]
  def change
    add_index :users, :uid, unique: true
    add_index :user_installations, [:user_id, :installation_id], unique: true
  end
end
