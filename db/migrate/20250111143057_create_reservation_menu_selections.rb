class CreateReservationMenuSelections < ActiveRecord::Migration[7.2]
  def change
    create_table :reservation_menu_selections do |t|
      t.references :menu, null: false, foreign_key: true
      t.references :reservation, null: false, foreign_key: true

      t.timestamps
    end
    add_index :reservation_menu_selections, [:menu_id, :reservation_id], unique: true
  end
end
