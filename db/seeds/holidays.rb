# frozen_string_literal: true

require 'factory_bot_rails'

holiday_settings = {
  "st@example.com"  => [1],
  "st2@example.com" => [2],
  "st3@example.com" => [1, 3]
}

holiday_settings.each do |email, chosen_wdays|
  stylist = User.find_by(email: email)
  existing = Holiday.where(stylist_id: stylist.id)
  existing.where.not(day_of_week: chosen_wdays).destroy_all

  chosen_wdays.each do |wday|
    holiday = Holiday.find_or_initialize_by(stylist_id: stylist.id, day_of_week: wday)
    holiday.save unless holiday.persisted?
  end
end

