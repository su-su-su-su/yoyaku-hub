class CreateAccountings < ActiveRecord::Migration[7.2]
  def change
    create_table :accountings do |t|
      t.references :reservation, null: false, foreign_key: true, index: { unique: true }
      t.decimal :total_amount, precision: 10, scale: 0, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
