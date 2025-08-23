class AddActiveToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :active, :boolean, default: true, null: false
    add_index :products, :active
  end
end
