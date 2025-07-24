class CreateAccountingPayments < ActiveRecord::Migration[7.2]
  def change
    create_table :accounting_payments do |t|
      t.references :accounting, null: false, foreign_key: true
      t.integer :payment_method, null: false
      t.decimal :amount, precision: 10, scale: 0, null: false

      t.timestamps
    end
  end
end
