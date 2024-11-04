# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { 'test@example.com' }
    password { 'testtest' }
    family_name { '予約' }
    given_name { '太郎' }
    family_name_kana { 'ヨヤク' }
    given_name_kana { 'タロウ' }
    gender { '男' }
    date_of_birth { Date.new(1987, 5, 3) }
    role { :stylist }
  end
end
