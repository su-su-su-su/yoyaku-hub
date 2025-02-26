# frozen_string_literal: true

class Menu < ApplicationRecord
  MAX_MENUS_PER_STYLIST = 30

  belongs_to :stylist, class_name: 'User'
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :reservations, through: :reservation_menu_selections

  validates :name, presence: true, uniqueness: { scope: :stylist_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_stylist_menu_limit, on: :create

  scope :by_stylist, ->(stylist) { where(stylist_id: stylist.id) }

  before_validation :assign_sort_order_if_blank
  before_save :shift_others, if: :will_save_change_to_sort_order?

  private

  def validate_stylist_menu_limit
    if stylist && stylist.menus.count >= MAX_MENUS_PER_STYLIST
      errors.add(:base, "メニューは最大#{MAX_MENUS_PER_STYLIST}件までです")
    end
  end

  def assign_sort_order_if_blank
    return if sort_order.present?

    used_orders = stylist.menus.where.not(id: id).pluck(:sort_order)
    available_order = (1..MAX_MENUS_PER_STYLIST).find { |num| used_orders.exclude?(num) }

    self.sort_order = available_order if available_order
  end

  def shift_others
    old_value = sort_order_was
    new_value = sort_order

    menus = stylist.menus.where.not(id: id)

    if old_value.nil?
      menus.where(sort_order: new_value..).update_all('sort_order = sort_order + 1')
    elsif new_value < old_value
      menus.where(sort_order: new_value...(old_value))
           .update_all('sort_order = sort_order + 1')
    elsif new_value > old_value
      menus.where(sort_order: (old_value + 1)..new_value)
           .update_all('sort_order = sort_order - 1')
    end
  end
end
