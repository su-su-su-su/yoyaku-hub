# frozen_string_literal: true

module Stylists
  class SchedulesController < ApplicationController
    def show
      date_param = params[:date]
      @date = begin
        Date.parse(date_param)
      rescue ArgumentError, TypeError
        Date.current
      end

      @time_slots = generate_time_slots('10:00', '18:00', 30)
      @stylist = current_user
    end

    private

    def generate_time_slots(start_str, end_str, step)
      start_time = Time.zone.parse(start_str)
      end_time   = Time.zone.parse(end_str)
      slots = []
      while start_time <= end_time
        slots << start_time.strftime('%H:%M')
        start_time += step.minutes
      end
      slots
    end
  end
end
