# frozen_string_literal: true

class Menu < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :reservations, through: :reservation_menu_selections

  validates :name, presence: true, uniqueness: { scope: :stylist_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, presence: true, numericality: { greater_than_or_equal_to: 0 }
  scope :by_stylist, ->(stylist) { where(stylist_id: stylist.id) }

  before_validation :assign_sort_order_if_blank

  before_save :shift_others, if: :will_save_change_to_sort_order?

  private

  def assign_sort_order_if_blank
    return if sort_order.present?

    used = stylist.menus.where.not(id: id).pluck(:sort_order)
    n = (1..30).find { |number| used.exclude?(number) }
    if n
      self.sort_order = n
    else
      errors.add(:base, 'メニューは最大30件までです')
    end
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
