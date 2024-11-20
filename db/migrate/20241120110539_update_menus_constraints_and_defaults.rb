class UpdateMenusConstraintsAndDefaults < ActiveRecord::Migration[7.2]
  def change
    change_column_null :menus, :name, false
    change_column_null :menus, :price, false
    change_column_null :menus, :duration, false
    change_column_default :menus, :is_active, true
  end
end
