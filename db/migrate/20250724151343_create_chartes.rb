class CreateChartes < ActiveRecord::Migration[7.2]
  def change
    create_table :chartes do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users }
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.references :reservation, null: false, foreign_key: true
      t.text :treatment_memo
      t.text :remarks

      t.timestamps
    end

    add_index :chartes, [:stylist_id, :customer_id]
  end
end
