# frozen_string_literal: true

FactoryBot.define do
  factory :menu do
    sequence(:name) { |n| "メニュー#{n}" }
    price { 5500 }
    duration { 60 }
    sequence(:description) { |n| "メニュー#{n}です" }
    category { %w[カット] }
    is_active { true }
    sequence(:sort_order) { |n| n }

    association :stylist, factory: %i[user stylist]

    trait :low_price do
      price { 3000 }
    end

    trait :high_price do
      price { 10_000 }
    end

    trait :short_duration do
      duration { 30 }
    end

    trait :long_duration do
      duration { 120 }
    end

    trait :cut do
      category { %w[カット] }
      duration { 60 }
      price { 6600 }
    end

    trait :color do
      category { %w[カラー] }
      duration { 90 }
      price { 8000 }
    end

    trait :perm do
      category { %w[パーマ] }
      duration { 100 }
      price { 9000 }
    end

    trait :multi_category do
      category { %w[カット カラー] }
      duration { 120 }
      price { 12_000 }
    end

    trait :inactive do
      is_active { false }
    end

    trait :without_description do
      description { nil }
    end
  end
end
