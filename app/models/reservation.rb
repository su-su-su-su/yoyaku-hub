# frozen_string_literal: true

class Reservation < ApplicationRecord
  belongs_to :customer, class_name: 'User', inverse_of: :reservations
  belongs_to :stylist,  class_name: 'User', inverse_of: :stylist_reservations
  has_many :reservation_menu_selections, dependent: :destroy
  has_many :menus, through: :reservation_menu_selections

  enum :status, { before_visit: 0, paid: 1, canceled: 2, no_show: 3 }

  validate :validate_not_holiday
  validate :validate_within_operating_hours
  validate :validate_slotwise_capacity
  validate :menu_selection_presence
  before_validation :combine_date_and_time

  attr_accessor :start_date_str, :start_time_str

  def combine_date_and_time
    return unless start_date_str.present? && start_time_str.present?

    begin
      new_start_at = Time.zone.parse("#{start_date_str} #{start_time_str}")
      self.start_at = new_start_at

      used_duration = custom_duration.presence || menus.sum(&:duration)
      self.end_at = new_start_at + used_duration.minutes
    rescue ArgumentError => e
      Rails.logger.warn("日時パースエラー: #{e.message}, 日付: #{start_date_str}, 時間: #{start_time_str}")
      errors.add(:start_date_str, :invalid)
      errors.add(:start_time_str, :invalid)
    end
  end

  def self.find_next_reservation_start_slot(stylist_id, date, from_slot)
    working_hour = WorkingHour.date_only_for(stylist_id, date)
    day_end_slot = if working_hour
                     to_slot_index(working_hour.end_time)
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
    working_hour = WorkingHour.date_only_for(stylist_id, date)
    day_start_slot = if working_hour
                       to_slot_index(working_hour.start_time)
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

  def self.safe_parse_date(date_string, default: Time.zone.today)
    return default if date_string.blank?

    begin
      Date.parse(date_string.to_s)
    rescue ArgumentError, TypeError => e
      Rails.logger.warn("日付パースエラー: #{e.message}, 入力値: #{date_string}")
      default
    end
  end

  private

  def validate_not_holiday
    return if start_at.blank?

    working_hour = WorkingHour.date_only_for(stylist_id, start_at.to_date)
    return unless working_hour.nil? || working_hour.start_time == working_hour.end_time

    errors.add(:base, '選択した日にちは休業日です')
  end

  def validate_within_operating_hours
    return if start_at.blank? || end_at.blank?
    return if errors.present?

    working_hour = WorkingHour.date_only_for(stylist_id, start_at.to_date)
    open_time  = working_hour.start_time.change(year: start_at.year, month: start_at.month, day: start_at.day)
    close_time = working_hour.end_time.change(year: start_at.year, month: start_at.month, day: start_at.day)
    errors.add(:base, '予約開始時刻が営業時間より早いです') if start_at < open_time
    errors.add(:base, '施術終了時刻が営業時間を超えています') if end_at > close_time
  end

  def validate_slotwise_capacity
    return if start_at.blank? || end_at.blank?
    return if errors.present?

    day = start_at.to_date

    current_usage = calculate_slot_usage_for(day)

    check_capacity_for_new_reservation(day, current_usage)
  end

  def menu_selection_presence
    return unless menu_ids.blank? || menu_ids.compact_blank.empty?

    errors.add(:menus, 'は1つ以上選択してください')
  end

  def calculate_slot_usage_for(day)
    usage = Hash.new(0)

    existing_reservations = Reservation.where(stylist_id: stylist_id)
      .where(status: %i[before_visit paid])
      .where.not(id: id)
      .where(start_at: day.all_day)

    existing_reservations.each do |reservation|
      start_slot = self.class.to_slot_index(reservation.start_at)
      end_slot   = self.class.to_slot_index(reservation.end_at)
      (start_slot...end_slot).each { |slot| usage[slot] += 1 }
    end

    usage
  end

  def check_capacity_for_new_reservation(day, usage)
    start_slot = self.class.to_slot_index(start_at)
    end_slot   = self.class.to_slot_index(end_at)

    (start_slot...end_slot).each do |slot|
      limit_record = ReservationLimit.find_by(stylist_id: stylist_id, target_date: day, time_slot: slot)
      capacity = limit_record&.max_reservations || 0

      if (usage[slot] + 1) > capacity
        errors.add(:base, 'この時間帯は既に受付上限を超えています。')
        break
      end
    end
  end
end
