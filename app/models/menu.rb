# frozen_string_literal: true

class Menu < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :reservations, through: :reservation_menu_selections

  validates :name, presence: true, uniqueness: { scope: :stylist_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, presence: true, numericality: { greater_than_or_equal_to: 0 }
  scope :by_stylist, ->(stylist) { where(stylist_id: stylist.id) }
end
