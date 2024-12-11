class CreateReservationLimits < ActiveRecord::Migration[7.2]
  def change
    create_table :reservation_limits do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users }
      t.date :target_date
      t.time :time_slot
      t.integer :max_reservations

      t.timestamps
    end
    add_index :reservation_limits, :target_date
  end
end
