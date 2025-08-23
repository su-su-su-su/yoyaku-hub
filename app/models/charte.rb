# frozen_string_literal: true

class Charte < ApplicationRecord
  belongs_to :stylist, class_name: 'User', inverse_of: :stylist_chartes
  belongs_to :customer, class_name: 'User', inverse_of: :customer_chartes
  belongs_to :reservation

  validates :reservation_id, uniqueness: true
  validates :treatment_memo, length: { maximum: 255 }
  validates :remarks, length: { maximum: 255 }

  scope :for_stylist, ->(stylist) { where(stylist: stylist) }
  scope :for_customer, ->(customer) { where(customer: customer) }
  scope :recent, -> { order(created_at: :desc) }

  def menu_names
    reservation.menus.pluck(:name)
  end

  def reservation_date
    reservation.start_at
  end

  def total_amount
    return nil unless reservation.accounting&.completed?

    reservation.accounting.total_amount
  end

  def accounting_products
    return [] unless reservation.accounting&.completed?

    reservation.accounting.accounting_products
  end

  def has_products?
    accounting_products.any?
  end
end
