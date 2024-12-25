class AddIsHolidayToHolidays < ActiveRecord::Migration[7.2]
  def change
    add_column :holidays, :is_holiday, :boolean, default: false, null: false
  end
end
