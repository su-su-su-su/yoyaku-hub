# frozen_string_literal: true

FactoryBot.define do
  factory :working_hour do
    association :stylist, factory: :user, role: :stylist
    start_time { Time.zone.parse('09:00') }
    end_time { Time.zone.parse('18:00') }
    target_date { nil }
    day_of_week { nil }
  end
end
