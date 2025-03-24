# frozen_string_literal: true

class ReservationLimit < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  validates :max_reservations, presence: true,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2
    }

  def self.default_for(stylist_id, date)
    rl = find_by(stylist_id: stylist_id, target_date: date)
    return rl if rl.present?

    global_rl = find_by(stylist_id: stylist_id, target_date: nil)
    if global_rl.present?
      return new(stylist_id: stylist_id, target_date: date, max_reservations: global_rl.max_reservations,
        time_slot: global_rl.time_slot)
    end

    new(stylist_id: stylist_id, target_date: date, max_reservations: 1)
  end
end
