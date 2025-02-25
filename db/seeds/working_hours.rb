# frozen_string_literal: true

require 'factory_bot_rails'

common_settings = {
  1 => { start_time: "11:00", end_time: "20:00" },
  2 => { start_time: "11:00", end_time: "20:00" },
  3 => { start_time: "11:00", end_time: "20:00" },
  4 => { start_time: "11:00", end_time: "20:00" },
  5 => { start_time: "11:00", end_time: "20:00" },
  6 => { start_time: "10:00", end_time: "20:00" },
  0 => { start_time: "10:00", end_time: "18:00" },
  7 => { start_time: "10:00", end_time: "18:00" }
}

st3_settings = {
  1 => { start_time: "12:00", end_time: "19:00" },
  2 => { start_time: "12:00", end_time: "19:00" },
  3 => { start_time: "12:00", end_time: "19:00" },
  4 => { start_time: "12:00", end_time: "19:00" },
  5 => { start_time: "12:00", end_time: "19:00" },
  6 => { start_time: "12:00", end_time: "18:00" },
  0 => { start_time: "12:00", end_time: "16:00" },
  7 => { start_time: "12:00", end_time: "16:00" }
}

User.where(role: 1).find_each do |stylist|
  settings = (stylist.email == "st3@example.com") ? st3_settings : common_settings

  settings.each do |wday, times|
    wh = WorkingHour.find_or_initialize_by(
      stylist_id: stylist.id,
      target_date: nil,
      day_of_week: wday
    )
    wh.start_time   = Time.zone.parse(times[:start_time])
    wh.end_time     = Time.zone.parse(times[:end_time])
    wh.holiday_flag = "0"
    wh.save!
  end
end
