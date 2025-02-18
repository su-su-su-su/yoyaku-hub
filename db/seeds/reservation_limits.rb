# frozen_string_literal: true

require 'factory_bot_rails'

reservation_limit_settings = {
  "st@example.com"  => 1,
  "st2@example.com" => 1,
  "st3@example.com" => 1
}

reservation_limit_settings.each do |email, max_limit|
  stylist = User.find_by(email: email)
  reservation_limit = ReservationLimit.find_or_initialize_by(stylist_id: stylist.id, target_date: nil)
  reservation_limit.max_reservations = max_limit
  reservation_limit.save
end
