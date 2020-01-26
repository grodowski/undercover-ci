class CreateNodes < ActiveRecord::Migration[6.0]
  def change
    create_table :nodes do |t|
      t.references :coverage_check, null: false
      t.string :path, null: false
      t.string :node_type, null: false
      t.string :node_name, null: false
      t.integer :start_line, null: false
      t.integer :end_line, null: false
      t.decimal :coverage, precision: 5, scale: 4, null: false
      t.boolean :flagged, null: false
      t.timestamps
    end
  end
end
