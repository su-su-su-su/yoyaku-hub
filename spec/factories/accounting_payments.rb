# frozen_string_literal: true

FactoryBot.define do
  factory :accounting_payment do
    accounting
    payment_method { :cash }
    amount { 1000 }
  end
end
