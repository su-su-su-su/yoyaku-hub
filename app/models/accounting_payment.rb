# frozen_string_literal: true

class AccountingPayment < ApplicationRecord
  belongs_to :accounting

  enum :payment_method, { cash: 0, credit_card: 1, digital_pay: 2, other: 3 }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
end
