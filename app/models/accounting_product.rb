# frozen_string_literal: true

class AccountingProduct < ApplicationRecord
  belongs_to :accounting
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :actual_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def total_price
    actual_price * quantity
  end
end
