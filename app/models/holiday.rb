# frozen_string_literal: true

class Holiday < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  def self.default_for(stylist_id, date)
    holiday = find_by(stylist_id: stylist_id, target_date: date)
    return holiday if holiday.present?

    if HolidayJp.holiday?(date)
      holiday_wh = find_by(stylist_id: stylist_id, day_of_week: 7, target_date: nil)
      if holiday_wh.present?
        return holiday_wh
      end
    end

    wday = date.wday
    find_by(stylist_id: stylist_id, day_of_week: wday, target_date: nil)
  end
end
