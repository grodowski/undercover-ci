class CreateInstallations < ActiveRecord::Migration[5.2]
  def change
    create_table :installations do |t|
      t.bigint :installation_id
      t.references :user, foreign_key: true
    end
  end
end
