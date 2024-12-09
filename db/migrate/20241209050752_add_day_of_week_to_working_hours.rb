class AddDayOfWeekToWorkingHours < ActiveRecord::Migration[7.2]
  def change
    add_column :working_hours, :day_of_week, :integer
  end
end
