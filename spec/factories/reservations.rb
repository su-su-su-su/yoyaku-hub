# frozen_string_literal: true

FactoryBot.define do
  factory :reservation do
    stylist { nil }
    customer { nil }
    start_at { '2025-01-08 01:22:22' }
    end_at { '2025-01-08 01:22:22' }
    status { 'MyString' }
  end
end
