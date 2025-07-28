# frozen_string_literal: true

FactoryBot.define do
  factory :charte do
    stylist factory: %i[stylist]
    customer factory: %i[customer]

    treatment_memo { '施術メモのサンプルテキストです' }
    remarks { '備考のサンプルテキストです' }

    before(:create) do |charte|
      unless charte.reservation
        reservation = build(:reservation, stylist: charte.stylist, customer: charte.customer)
        reservation.save!(validate: false)
        charte.reservation = reservation
      end
    end

    trait :with_completed_accounting do
      after(:create) do |charte|
        create(:accounting, :completed, reservation: charte.reservation, total_amount: 5000)
      end
    end
  end
end
