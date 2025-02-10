class AddCustomDurationToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :custom_duration, :integer
  end
end
