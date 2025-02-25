# frozen_string_literal: true

require 'factory_bot_rails'

customer = User.find_by(email: 'ca@example.com')

stylist = User.find_by(email: 'st@example.com')

menu1 = stylist.menus.first
menu2 = stylist.menus.second

menu_ids = [menu1.id, menu2.id]
total_duration = menu1.duration + menu2.duration

upcoming_date = Time.zone.today + 2.days
upcoming_start_time = Time.zone.parse("#{upcoming_date} 13:00")
upcoming_reservation = Reservation.create!(
  customer_id: customer.id,
  stylist_id: stylist.id,
  menu_ids: menu_ids,
  start_at: upcoming_start_time,
  end_at: upcoming_start_time + total_duration.minutes,
  status: Reservation.statuses[:before_visit]
)
upcoming_reservation.menu_ids = menu_ids
upcoming_reservation.save!

past_date = Time.zone.today - 3.days
past_start_time = Time.zone.parse("#{past_date} 11:00")
past_reservation = Reservation.create!(
  customer_id: customer.id,
  stylist_id: stylist.id,
  menu_ids: menu_ids,
  start_at: past_start_time,
  end_at: past_start_time + total_duration.minutes,
  status: Reservation.statuses[:paid]
)
past_reservation.menu_ids = menu_ids
past_reservation.save!
