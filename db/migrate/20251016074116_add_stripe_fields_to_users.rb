class AddStripeFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :stripe_customer_id, :string
    add_column :users, :stripe_subscription_id, :string
    add_column :users, :subscription_status, :string
    add_column :users, :trial_ends_at, :datetime

    add_index :users, :stripe_customer_id, unique: true
    add_index :users, :stripe_subscription_id
    add_index :users, :subscription_status
  end
end
