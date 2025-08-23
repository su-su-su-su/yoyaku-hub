# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    user factory: %i[user]
    sequence(:name) { |n| "商品#{n}" }
    default_price { 3000 }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :expensive do
      default_price { 10_000 }
    end
  end
end
