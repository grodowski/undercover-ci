class CreateUserInstallations < ActiveRecord::Migration[6.0]
  def change
    create_table :user_installations do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :installation, null: false, foreign_key: true, index: true

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        # assumes no duplicates in `installations`
        Installation.find_each do |inst|
          UserInstallation.create!(installation_id: inst.id, user_id: inst.user_id)
        end
      end
    end

    remove_reference :installations, :user, index: true, foreign_key: true
  end
end
