# frozen_string_literal: true

class AddDetailsToUsers < ActiveRecord::Migration[7.2]
  def change
    change_table :users, bulk: true do |t|
      t.string :family_name
      t.string :given_name
      t.string :family_name_kana
      t.string :given_name_kana
      t.string :gender
      t.date :date_of_birth
      t.integer :role
      t.string :provider
      t.string :uid
    end
  end
end
