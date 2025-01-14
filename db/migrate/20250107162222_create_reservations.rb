class CreateReservations < ActiveRecord::Migration[7.2]
  def change
    create_table :reservations do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users } 
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.datetime :start_at
      t.datetime :end_at
      t.string :status

      t.timestamps
    end

    add_index :reservations, :start_at
    add_index :reservations, :end_at
  end
end
