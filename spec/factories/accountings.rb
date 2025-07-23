# frozen_string_literal: true

FactoryBot.define do
  factory :accounting do
    reservation
    total_amount { 5000 }
    status { :pending }
  end
end
