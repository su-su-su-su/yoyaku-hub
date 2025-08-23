# frozen_string_literal: true

FactoryBot.define do
  factory :accounting do
    reservation
    total_amount { 5000 }
    status { :pending }

    trait :completed do
      status { :completed }
    end

    trait :with_payment do
      after(:create) do |accounting|
        create(:accounting_payment, accounting: accounting, amount: accounting.total_amount)
      end
    end
  end
end
