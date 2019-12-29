class CreateNodes < ActiveRecord::Migration[6.0]
  def change
    create_table :nodes do |t|
      t.references :coverage_check, null: false
      t.string :path, null: false
      t.string :node_type, null: false
      t.integer :start_line, null: false
      t.integer :end_line, null: false
      t.decimal :coverage, precision: 5, scale: 2, null: false
      t.decimal :diff_coverage, precision: 5, scale: 2, null: false
      t.timestamps
    end
  end
end
