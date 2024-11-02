class AddDetailsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :family_name, :string
    add_column :users, :given_name, :string
    add_column :users, :family_name_kana, :string
    add_column :users, :given_name_kana, :string
    add_column :users, :gender, :string
    add_column :users, :date_of_birth, :date
    add_column :users, :role, :integer
    add_column :users, :provider, :string
    add_column :users, :uid, :string
  end
end
