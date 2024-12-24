# frozen_string_literal: true

class WorkingHour < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  def self.default_for(stylist_id, date)
    wh = find_by(stylist_id: stylist_id, target_date: date)
    return wh if wh.present?

    if HolidayJp.holiday?(date)
      holiday_wh = find_by(stylist_id: stylist_id, day_of_week: 7, target_date: nil)
      return holiday_wh if holiday_wh.present?
    end

    wday = date.wday
    default_wday_wh = find_by(stylist_id: stylist_id, day_of_week: wday, target_date: nil)
    return default_wday_wh if default_wday_wh.present?

    new(
      stylist_id: stylist_id,
      target_date: date,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('18:00')
    )
  end

  private

  def end_time_after_start_time
    return unless start_time >= end_time

    errors.add(:end_time, 'は開始時間より後に設定してください')
  end
end
