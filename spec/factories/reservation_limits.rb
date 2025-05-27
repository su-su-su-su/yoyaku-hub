# frozen_string_literal: true

FactoryBot.define do
  factory :reservation_limit do
    stylist factory: %i[user], role: :stylist
    target_date { nil }
    max_reservations { 1 }
    time_slot { nil }
  end
end
