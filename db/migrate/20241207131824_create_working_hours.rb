class CreateWorkingHours < ActiveRecord::Migration[7.2]
  def change
    create_table :working_hours do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users }
      t.date :target_date
      t.time :start_time
      t.time :end_time

      t.timestamps
    end
    add_index :working_hours, :target_date
    add_index :working_hours, [:stylist_id, :target_date], unique: true
  end
end
