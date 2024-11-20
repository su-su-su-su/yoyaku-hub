class CreateMenus < ActiveRecord::Migration[7.2]
  def change
    create_table :menus do |t|
      t.references :stylist, null: false, foreign_key: { to_table: :users }
      t.string :name
      t.integer :price
      t.integer :duration
      t.text :description
      t.string :category, array: true, default: [] 
      t.integer :sort_order
      t.boolean :is_active

      t.timestamps
    end
  end
end
