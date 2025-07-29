class AddCreatedByStylistIdToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :created_by_stylist, null: true, foreign_key: { to_table: :users }
  end
end
