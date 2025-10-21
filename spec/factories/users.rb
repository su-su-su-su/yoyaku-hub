# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'testtest' }
    password_confirmation { 'testtest' }

    family_name { '美容師' }
    given_name { '太郎' }

    family_name_kana { 'ビヨウシ' }
    given_name_kana { 'タロウ' }

    gender { '男' }
    date_of_birth { Date.new(2000, 4, 10) }

    role { :stylist }

    trait :with_kana do
      family_name_kana { 'ビヨウシ' }
      given_name_kana { 'タロウ' }
    end

    trait :with_invalid_kana do
      family_name_kana { 'biyoshi' }
      given_name_kana { 'taro' }
    end

    trait :customer do
      role { :customer }
      # カスタマーはサブスクリプション関連フィールドをnilに
      subscription_exempt { false }
      subscription_exempt_reason { nil }
      stripe_customer_id { nil }
      stripe_subscription_id { nil }
      subscription_status { nil }
    end

    trait :stylist do
      role { :stylist }
    end

    trait :with_oauth do
      provider { 'google_oauth2' }
      sequence(:uid) { |n| "12345#{n}" }
    end

    trait :female do
      gender { '女' }
    end

    factory :customer, traits: [:customer]
    factory :stylist, traits: [:stylist]
  end
end
# rubocop:enable Metrics/BlockLength
