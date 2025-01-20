# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :customer, class_name: 'User', inverse_of: :reservations

  belongs_to :stylist, class_name: 'User', inverse_of: :stylist_reservations

  has_many :reservation_menu_selections, dependent: :destroy
  has_many :menus, through: :reservation_menu_selections

  def self.find_next_reservation_start_slot(stylist_id, date, from_slot)
    day_start = date.beginning_of_day
    day_end = date.end_of_day
    reservations_in_day = where(stylist_id: stylist_id).where(start_at: day_start..day_end)

    start_slots = reservations_in_day.map do |res|
      (res.start_at.hour * 2) + (res.start_at.min >= 30 ? 1 : 0)
    end
    next_start_slots = start_slots.select { |slot| slot >= from_slot }

    next_start_slots.min || 48
  end

  def self.find_previous_reservation_end_slot(stylist_id, date, from_slot)
    day_start = date.beginning_of_day
    day_end = date.end_of_day
    reservations_in_day = where(stylist_id: stylist_id).where(start_at: day_start..day_end)

    end_slots = reservations_in_day.map do |res|
      (res.end_at.hour * 2) + (res.end_at.min >= 30 ? 1 : 0)
    end
    prev_end_slots = end_slots.select { |s| s <= from_slot }

    prev_end_slots.max || 0
  end
end
