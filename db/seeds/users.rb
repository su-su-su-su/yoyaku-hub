# frozen_string_literal: true

require 'factory_bot_rails'

users_data = [
  {
    email: "ca@example.com",
    password: "testtest",
    family_name: "予約",
    given_name: "太郎",
    family_name_kana: "ヨヤク",
    given_name_kana: "タロウ",
    gender: "male",
    date_of_birth: Date.new(2000, 1, 1),
    role: 0
  },
  {
    email: "ca2@example.com",
    password: "testtest",
    family_name: "予約",
    given_name: "次郎",
    family_name_kana: "ヨヤク",
    given_name_kana: "ジロウ",
    gender: "male",
    date_of_birth: Date.new(2000, 1, 2),
    role: 0
  },
  {
    email: "ca3@example.com",
    password: "testtest",
    family_name: "予約",
    given_name: "花子",
    family_name_kana: "ヨヤク",
    given_name_kana: "ハナコ",
    gender: "female",
    date_of_birth: Date.new(2000, 1, 3),
    role: 0
  },
  {
    email: "st@example.com",
    password: "testtest",
    family_name: "美容師",
    given_name: "太郎",
    family_name_kana: "ビヨウシ",
    given_name_kana: "タロウ",
    gender: "male",
    date_of_birth: Date.new(2001, 1, 1),
    role: 1 
  },
  {
    email: "st2@example.com",
    password: "testtest",
    family_name: "美容師",
    given_name: "次郎",
    family_name_kana: "ビヨウシ",
    given_name_kana: "ジロウ",
    gender: "male",
    date_of_birth: Date.new(2001, 1, 2),
    role: 1 
  },
  {
    email: "st3@example.com",
    password: "testtest",
    family_name: "美容師",
    given_name: "花子",
    family_name_kana: "ビヨウシ",
    given_name_kana: "ハナコ",
    gender: "female",
    date_of_birth: Date.new(2001, 1, 3),
    role: 1 
  },
]

users_data.each do |attrs|
  user = User.find_by(email: attrs[:email])
  user = FactoryBot.create(:user, attrs) if user.nil?
end
