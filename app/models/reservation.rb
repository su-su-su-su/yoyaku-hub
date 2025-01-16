# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :customer, class_name: 'User', inverse_of: :reservations

  belongs_to :stylist, class_name: 'User', inverse_of: :stylist_reservations

  has_many :reservation_menu_selections, dependent: :destroy
  has_many :menus, through: :reservation_menu_selections
end
