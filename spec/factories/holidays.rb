# frozen_string_literal: true

FactoryBot.define do
  factory :holiday do
    stylist { nil }
    target_date { '2024-12-10' }
    day_of_week { 1 }
  end
end
