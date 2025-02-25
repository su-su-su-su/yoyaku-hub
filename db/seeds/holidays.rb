# frozen_string_literal: true

require 'factory_bot_rails'

holiday_settings = {
  "st@example.com" => [1],
  "st2@example.com" => [2],
  "st3@example.com" => [1, 3]
}

start_date = Date.today.beginning_of_month
end_date = Date.today.end_of_month

holiday_settings.each do |email, chosen_wdays|
  stylist = User.find_by(email: email)
  next unless stylist

  (start_date..end_date).each do |date|
    if chosen_wdays.include?(date.wday)
      holiday = Holiday.find_or_initialize_by(stylist_id: stylist.id, target_date: date)
      holiday.is_holiday = true
      holiday.day_of_week = date.wday
      holiday.save!
    end
  end
end
