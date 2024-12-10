class CreateHolidays < ActiveRecord::Migration[7.2]
  def change
    create_table :holidays do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users }
      t.date :target_date
      t.integer :day_of_week

      t.timestamps
    end
    add_index :holidays, :target_date
    add_index :holidays, [:stylist_id, :target_date], unique: true
  end
end
