class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :default_price, null: false

      t.timestamps
    end

    add_index :products, [:user_id, :name]
  end
end
