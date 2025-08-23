# frozen_string_literal: true

FactoryBot.define do
  factory :accounting_product do
    accounting
    product
    quantity { 1 }
    actual_price { 3000 }

    trait :discounted do
      actual_price { 2000 }
    end

    trait :multiple do
      quantity { 3 }
    end
  end
end
