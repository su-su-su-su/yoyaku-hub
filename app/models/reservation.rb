# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :customer, class_name: 'User', inverse_of: :reservations
  belongs_to :stylist, class_name: 'User', inverse_of: :stylist_reservations
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :menus, through: :reservation_menu_selections

  enum :status, { before_visit: 0, paid: 1, canceled: 2, no_show: 3 }

  attr_accessor :start_date_str, :start_time_str
  before_validation :combine_date_and_time

  def self.find_next_reservation_start_slot(stylist_id, date, from_slot)
    working_hr = WorkingHour.date_only_for(stylist_id, date)
    day_end_slot = if working_hr
                     to_slot_index(working_hr.end_time)
                   else
                     48
                   end

    day_start = date.beginning_of_day
    day_end   = date.end_of_day

    reservations_in_day = where(stylist_id: stylist_id)
                          .where(status: %i[before_visit paid])
                          .where(start_at: day_start..day_end)

    start_slots = reservations_in_day.map do |res|
      to_slot_index(res.start_at)
    end

    next_start_slots = start_slots.select { |slot| slot >= from_slot }

    next_start_slots.min || day_end_slot
  end

  def self.find_previous_reservation_end_slot(stylist_id, date, from_slot)
    working_hr = WorkingHour.date_only_for(stylist_id, date)
    day_start_slot = if working_hr
                       to_slot_index(working_hr.start_time)
                     else
                       0
                     end

    day_start = date.beginning_of_day
    day_end   = date.end_of_day

    reservations_in_day = where(stylist_id: stylist_id)
                          .where(status: %i[before_visit paid])
                          .where(start_at: day_start..day_end)

    end_slots = reservations_in_day.map do |res|
      to_slot_index(res.end_at)
    end

    prev_end_slots = end_slots.select { |slot| slot <= from_slot }

    prev_end_slots.max || day_start_slot
  end

  def self.to_slot_index(time)
    (time.hour * 2) + (time.min >= 30 ? 1 : 0)
  end

  private

  def combine_date_and_time
    if start_date_str.present? && start_time_str.present?
      new_start_at = Time.zone.parse("#{start_date_str} #{start_time_str}")
      self.start_at = new_start_at

      total_duration = menus.sum(&:duration)
      self.end_at = new_start_at + total_duration.minutes
    end
  end
end
