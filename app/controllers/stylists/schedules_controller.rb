# frozen_string_literal: true

module Stylists
  class SchedulesController < ApplicationController
    def show
      @date = begin
        Date.parse(params[:date])
      rescue StandardError
        Date.current
      end

      @stylist = current_user
      @is_holiday = Holiday.default_for(@stylist.id, @date)

      if @is_holiday
        @time_slots = []
        @working_hour = nil
      else
        @working_hour = WorkingHour.date_only_for(@stylist.id, @date)
        if @working_hour.nil?
          @time_slots = []
        else
          start_str = @working_hour.start_time.strftime('%H:%M')
          end_str   = @working_hour.end_time.strftime('%H:%M')
          @time_slots = generate_time_slots(start_str, end_str, 30)
        end
      end
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
