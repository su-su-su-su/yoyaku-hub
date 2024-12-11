# frozen_string_literal: true

module Stylists
  class ShiftSettingsController < StylistsController
    before_action :authenticate_user!

    def show
      wday_example = 1
      weekday_wh = WorkingHour.find_by(stylist_id: current_user.id, day_of_week: wday_example)
      if weekday_wh
        @weekday_start_str = weekday_wh.start_time.strftime('%H:%M')
        @weekday_end_str = weekday_wh.end_time.strftime('%H:%M')
      else
        @weekday_start_str = '09:00'
        @weekday_end_str = '18:00'
      end

      sat_wh = WorkingHour.find_by(stylist_id: current_user.id, day_of_week: 6)
      if sat_wh
        @saturday_start_str = sat_wh.start_time.strftime('%H:%M')
        @saturday_end_str = sat_wh.end_time.strftime('%H:%M')
      else
        @saturday_start_str = '09:00'
        @saturday_end_str = '18:00'
      end

      sun_wh = WorkingHour.find_by(stylist_id: current_user.id, day_of_week: 0)
      if sun_wh
        @sunday_start_str = sun_wh.start_time.strftime('%H:%M')
        @sunday_end_str = sun_wh.end_time.strftime('%H:%M')
      else
        @sunday_start_str = '09:00'
        @sunday_end_str = '18:00'
      end

      @time_options = (0..47).map do |i|
        hour = i / 2
        minute = (i % 2) * 30
        time_str = format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
        [time_str, time_str]
      end

      @chosen_wdays = Holiday.where(stylist_id: current_user.id).pluck(:day_of_week)

      @current_limit = ReservationLimit.find_by(stylist_id: current_user.id)

    end
  end
end
