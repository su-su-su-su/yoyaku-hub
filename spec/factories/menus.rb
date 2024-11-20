# frozen_string_literal: true

FactoryBot.define do
  factory :menu do
    stylist { nil }
    name { 'MyString' }
    price { 1 }
    duration { 1 }
    description { 'MyText' }
    category { 'MyString' }
    sort_order { 1 }
    is_active { false }
  end
end
