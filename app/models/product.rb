# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :user
  has_many :accounting_products, dependent: :restrict_with_error
  has_many :accountings, through: :accounting_products

  validates :name, presence: true
  validates :default_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
end
