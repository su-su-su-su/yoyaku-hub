# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
FactoryBot.define do
  factory :reservation do
    customer { association :user, role: :customer }
    stylist { association :user, role: :stylist }
    status { :before_visit }

    start_at { Time.zone.now.change(hour: 10, min: 0) }

    end_at { start_at + 60.minutes }

    after(:build) do |reservation, _evaluator|
      if reservation.stylist.present? && reservation.menu_ids.blank?
        menu = create(:menu, stylist: reservation.stylist, is_active: true)
        reservation.menu_ids = [menu.id]
      end
    end

    trait :with_menus do
      transient do
        menu_count { 1 }
      end

      after(:build) do |reservation, evaluator|
        menus = create_list(:menu, evaluator.menu_count, stylist: reservation.stylist, is_active: true)
        reservation.menu_ids = menus.map(&:id)

        total_duration = menus.sum(&:duration)
        reservation.end_at = reservation.start_at + total_duration.minutes
      end
    end

    trait :with_string_date_time do
      transient do
        date_str { Date.current.to_s }
        time_str { '10:00' }
      end

      after(:build) do |reservation, evaluator|
        reservation.start_date_str = evaluator.date_str
        reservation.start_time_str = evaluator.time_str
      end
    end

    trait :with_custom_duration do
      transient do
        duration { 120 }
      end

      custom_duration { duration }
      end_at { start_at + duration.minutes }
    end

    trait :before_visit do
      status { :before_visit }
    end

    trait :paid do
      status { :paid }
    end

    trait :canceled do
      status { :canceled }
    end

    trait :no_show do
      status { :no_show }
    end
  end
end
# rubocop:enable Metrics/BlockLength
