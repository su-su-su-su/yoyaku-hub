class AddUniqueIndexToChartesReservationId < ActiveRecord::Migration[7.2]
  def change
    remove_index :chartes, :reservation_id if index_exists?(:chartes, :reservation_id)
    add_index :chartes, :reservation_id, unique: true
  end
end
