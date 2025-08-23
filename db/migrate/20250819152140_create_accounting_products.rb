class CreateAccountingProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounting_products do |t|
      t.references :accounting, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.integer :actual_price, null: false

      t.timestamps
    end

    add_index :accounting_products, [:accounting_id, :product_id]
  end
end
