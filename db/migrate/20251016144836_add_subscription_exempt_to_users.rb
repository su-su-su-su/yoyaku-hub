class AddSubscriptionExemptToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :subscription_exempt, :boolean, default: false, null: false
    add_column :users, :subscription_exempt_reason, :string
    add_column :users, :trial_used, :boolean, default: false, null: false

    add_index :users, :subscription_exempt
  end
end
