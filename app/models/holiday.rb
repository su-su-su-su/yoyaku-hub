# frozen_string_literal: true

class Holiday < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  def self.default_for(stylist_id, date)
    rec = find_by(stylist_id: stylist_id, target_date: date)
    return rec.is_holiday? if rec.present?

    if HolidayJp.holiday?(date)
      holiday_wh = find_by(stylist_id: stylist_id, day_of_week: 7, target_date: nil)
      return holiday_wh if holiday_wh.present?
    end

    wday = date.wday
    weekday_holiday = find_by(stylist_id: stylist_id, day_of_week: wday, target_date: nil)
    return true if weekday_holiday.present?

    false
  end
end
