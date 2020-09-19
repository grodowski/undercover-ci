class CreateSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :subscriptions do |t|
      t.references :installation, null: false, foreign_key: true, index: true, unique: true
      t.string :gumroad_id
      t.string :state
      t.datetime :end_date
      t.jsonb :state_log

      # TODO: store amount?

      t.timestamps
    end
  end
end
