class ChangeTimeSlotToIntegerInReservationLimits < ActiveRecord::Migration[7.2]
  def change
    remove_column :reservation_limits, :time_slot, :time
    add_column :reservation_limits, :time_slot, :integer
  end
end
