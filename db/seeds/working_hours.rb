# frozen_string_literal: true

require 'factory_bot_rails'

stylist_emails = ["st@example.com", "st2@example.com", "st3@example.com"]

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

stylist_emails.each do |email|
  stylist = User.find_by(email: email)
  settings = email == "st3@example.com" ? st3_settings : common_settings

  settings.each do |day_of_week, times|
    wh = WorkingHour.find_or_initialize_by(stylist_id: stylist.id, day_of_week: day_of_week)
    wh.start_time = Time.zone.parse(times[:start_time])
    wh.end_time   = Time.zone.parse(times[:end_time])
    wh.save
  end
end
