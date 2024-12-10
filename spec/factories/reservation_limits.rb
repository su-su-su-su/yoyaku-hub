# frozen_string_literal: true

FactoryBot.define do
  factory :reservation_limit do
    stylist { nil }
    target_date { '2024-12-10' }
    time_slot { '2024-12-10 16:15:29' }
    max_reservations { 1 }
  end
end
