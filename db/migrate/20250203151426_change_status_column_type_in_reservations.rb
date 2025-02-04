# db/migrate/20250203151426_change_status_column_type_in_reservations.rb
class ChangeStatusColumnTypeInReservations < ActiveRecord::Migration[7.2]
  def up
    change_column :reservations, :status, 'integer USING CAST(status AS integer)'
    change_column_default :reservations, :status, from: nil, to: 0
  end

  def down
    change_column :reservations, :status, :string
    change_column_default :reservations, :status, from: 0, to: nil
  end
end
