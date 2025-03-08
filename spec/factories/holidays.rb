# frozen_string_literal: true

FactoryBot.define do
  factory :holiday do
    association :stylist, factory: :user, role: :stylist
    day_of_week { nil }
    target_date { nil }
    is_holiday { true }
  end
end
