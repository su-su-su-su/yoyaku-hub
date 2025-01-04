# frozen_string_literal: true

module Customers
  module Stylists
    class WeekliesController < ApplicationController
      def index
        set_stylist
        set_selected_menus
        set_dates_and_time_slots

        fetch_working_hours
        fetch_holidays
        filter_non_holiday_working_hours
        calculate_time_slots
        build_working_hours_hash
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
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
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
    end
  end
end
