class AddUniqueIndexToMenus < ActiveRecord::Migration[7.2]
  def change
    add_index :menus, [:stylist_id, :name], unique: true, name: 'index_menus_on_stylist_id_and_name'
  end
end
