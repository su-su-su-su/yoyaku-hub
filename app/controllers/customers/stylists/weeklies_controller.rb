# frozen_string_literal: true

module Customers
  module Stylists
    class WeekliesController < ApplicationController
      helper_method :total_duration, :within_working_hours?
      def index
        set_stylist
        set_selected_menus
        set_dates_and_time_slots

        fetch_working_hours
        fetch_holidays
        filter_non_holiday_working_hours
        calculate_time_slots
        build_working_hours_hash
        build_reservation_limits_hash
        set_can_go_previous
      end

      private

      def set_stylist
        @stylist = User.find(params[:stylist_id])
      end

      def set_selected_menus
        @selected_menu_ids = params[:menu_ids] || []
        @selected_menus    = @stylist.menus.where(id: @selected_menu_ids)
      end

      def set_dates_and_time_slots
        if params[:start_date].present?
          parsed_date = Date.parse(params[:start_date])
          parsed_start_date = parsed_date.beginning_of_week
          current_week_start = Date.current.beginning_of_week
          @start_date = [parsed_start_date, current_week_start].max
        else
          @start_date = Date.current.beginning_of_week
        end
        @dates = (@start_date..(@start_date + 6.days)).to_a
      end

      def fetch_working_hours
        @wh_list = WorkingHour.where(stylist_id: @stylist.id, target_date: @dates).order(:start_time)
      end

      def fetch_holidays
        holiday_records = Holiday.where(stylist_id: @stylist.id, target_date: @dates, is_holiday: true)
        @holiday_days = holiday_records.to_set(&:target_date)
      end

      def filter_non_holiday_working_hours
        @wh_non_holiday = @wh_list.reject { |wh| @holiday_days.include?(wh.target_date) }
      end

      def calculate_time_slots
        earliest_start = @wh_non_holiday.map(&:start_time).compact_blank.min
        latest_end     = @wh_non_holiday.map(&:end_time).compact_blank.max

        @time_slots = []
        current_time = earliest_start
        while current_time < latest_end
          @time_slots << current_time.strftime('%H:%M')
          current_time += 30.minutes
        end
      end

      def build_working_hours_hash
        @working_hours_hash = {}
        @wh_list.each do |wh|
          @working_hours_hash[wh.target_date] = wh
        end
      end

      def build_reservation_limits_hash
        limits = ReservationLimit.where(stylist_id: @stylist.id, target_date: @dates)
        @reservation_limits_hash = {}

        @dates.each do |date|
          @reservation_limits_hash[date] = {}
        end

        limits.each do |limit|
          next if limit.time_slot.nil?

          @reservation_limits_hash[limit.target_date][limit.time_slot] = limit
        end
      end

      def set_can_go_previous
        current_week_start = Date.current.beginning_of_week
        @can_go_previous = @start_date > current_week_start
      end

      def total_duration
        @selected_menus.sum(&:duration)
      end

      def within_working_hours?(working_hours, date, time_str, total_minutes)
        if date < Date.current
          return false
        elsif date == Date.current
          cutoff_time = 1.hour.from_now
          slot_time = Time.zone.parse("#{date} #{time_str}")
          return false if slot_time < cutoff_time
        end

        day_start_hm = working_hours.start_time.strftime('%H:%M')
        day_end_hm = working_hours.end_time.strftime('%H:%M')

        start_time = Time.zone.parse("#{date} #{time_str}")
        end_time   = start_time + total_minutes.minutes

        (time_str >= day_start_hm) && (end_time.strftime('%H:%M') <= day_end_hm)
      end
    end
  end
end
