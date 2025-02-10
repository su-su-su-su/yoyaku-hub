# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :customer, class_name: 'User', inverse_of: :reservations
  belongs_to :stylist, class_name: 'User', inverse_of: :stylist_reservations
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :menus, through: :reservation_menu_selections

  enum :status, { before_visit: 0, paid: 1, canceled: 2, no_show: 3 }

  validate :validate_not_holiday
  validate :validate_within_operating_hours
  validate :validate_slotwise_capacity
  validate :menu_selection_presence
  before_validation :combine_date_and_time

  attr_accessor :start_date_str, :start_time_str

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
    return unless start_date_str.present? && start_time_str.present?

    new_start_at = Time.zone.parse("#{start_date_str} #{start_time_str}")
    self.start_at = new_start_at

    used_duration = custom_duration.presence || menus.sum(&:duration)
    self.end_at = new_start_at + used_duration.minutes
  end

  def validate_not_holiday
    return if start_at.blank?

    working_hour = WorkingHour.date_only_for(stylist_id, start_at.to_date)
    return unless working_hour.nil? || working_hour.start_time == working_hour.end_time

    errors.add(:base, '選択した日にちは休業日です')
  end

  def validate_within_operating_hours
    return if start_at.blank? || end_at.blank?
    return if errors.present?

    w = WorkingHour.date_only_for(stylist_id, start_at.to_date)
    open_time  = w.start_time.change(year: start_at.year, month: start_at.month, day: start_at.day)
    close_time = w.end_time.change(year: start_at.year, month: start_at.month, day: start_at.day)
    errors.add(:base, '予約開始時刻が営業時間より早いです') if start_at < open_time
    errors.add(:base, '施術終了時刻が営業時間を超えています') if end_at > close_time
  end

  def validate_slotwise_capacity
    return if start_at.blank? || end_at.blank?
    return if errors.present?

    day = start_at.to_date
    WorkingHour.date_only_for(stylist_id, day)
    s_idx = self.class.to_slot_index(start_at)
    e_idx = self.class.to_slot_index(end_at)
    usage = Hash.new(0)
    existing = Reservation
               .where(stylist_id: stylist_id)
               .where(status: %i[before_visit paid])
               .where.not(id: id)
               .where(start_at: day.all_day)
    existing.each do |res|
      start_i = self.class.to_slot_index(res.start_at)
      end_i   = self.class.to_slot_index(res.end_at)
      (start_i...end_i).each { |slot| usage[slot] += 1 }
    end
    (s_idx...e_idx).each do |slot|
      limit_rec = ReservationLimit.find_by(stylist_id: stylist_id, target_date: day, time_slot: slot)
      max_res = limit_rec&.max_reservations || 0
      if (usage[slot] + 1) > max_res
        errors.add(:base, 'この時間帯は既に受付上限を超えています。')
        break
      end
    end
  end
  def menu_selection_presence
    if menu_ids.blank? || menu_ids.reject(&:blank?).empty?
      errors.add(:menus, 'は1つ以上選択してください')
    end
  end
end
