# frozen_string_literal: true

module Customers
  module Stylists
    class WeekliesController < ApplicationController
      before_action :authenticate_user!
      before_action -> { ensure_role(:customer) }
      before_action :set_stylist
      before_action :set_selected_menus
      before_action :set_dates_and_time_slots
      before_action :load_schedule_data

      helper_method :within_reservation_limits?, :total_duration, :within_working_hours?

      def index
        @time_slots = build_time_slots_for_week(@dates)
      end

      private

      def set_stylist
        @stylist = User.find(params[:stylist_id])
      end

      def set_selected_menus
        @selected_menu_ids = params[:menu_ids] || []
        @selected_menus = @stylist.menus.where(id: @selected_menu_ids)
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
        set_can_go_previous
      end

      def load_schedule_data
        fetch_working_hours
        fetch_holidays
        filter_non_holiday_working_hours
        build_working_hours_hash
        build_reservation_limits_hash
        build_reservation_counts
        prepare_occupied_slots
      end

      def fetch_working_hours
        @wh_list = WorkingHour.where(stylist_id: @stylist.id, target_date: @dates).order(:start_time)
      end

      def fetch_holidays
        holiday_records = Holiday.where(stylist_id: @stylist.id, target_date: @dates, is_holiday: true)
        @holiday_days = holiday_records.pluck(:target_date).to_set
      end

      def filter_non_holiday_working_hours
        @wh_non_holiday = @wh_list.reject { |wh| @holiday_days.include?(wh.target_date) }
      end

      def build_working_hours_hash
        @working_hours_hash = @wh_list.index_by(&:target_date)
      end

      def build_reservation_limits_hash
        limits = ReservationLimit.where(stylist_id: @stylist.id, target_date: @dates)
        @reservation_limits_hash = @dates.each_with_object({}) do |date, hash|
          hash[date] = {}
        end

        limits.each do |limit|
          next if limit.time_slot.nil?
          @reservation_limits_hash[limit.target_date][limit.time_slot] = limit
        end
      end

      def build_reservation_counts
        @reservation_counts = @dates.each_with_object({}) do |date, counts|
          counts[date] = {}

          reservations = fetch_active_reservations_for_date(date)

          reservations.each do |res|
            start_slot = slot_for_time(res.start_at)
            end_slot = slot_for_time(res.end_at)

            (start_slot...end_slot).each do |s|
              counts[date][s] ||= 0
              counts[date][s] += 1
            end
          end
        end
      end

      def fetch_active_reservations_for_date(date)
        Reservation.where(
          stylist_id: @stylist.id,
          start_at: date.beginning_of_day..date.end_of_day,
          status: [:before_visit, :paid]
        )
      end

      def set_can_go_previous
        current_week_start = Date.current.beginning_of_week
        @can_go_previous = @start_date > current_week_start
      end

      def total_duration
        @selected_menus.sum(&:duration)
      end

      def within_working_hours?(working_hours, date, time_str, total_minutes)
        return false if date < Date.current

        if date == Date.current
          cutoff_time = 1.hour.from_now
          slot_time = Time.zone.parse("#{date} #{time_str}")
          return false if slot_time < cutoff_time
        end

        day_start_hm = working_hours.start_time.strftime('%H:%M')
        day_end_hm = working_hours.end_time.strftime('%H:%M')
        start_time = Time.zone.parse("#{date} #{time_str}")
        end_time = start_time + total_minutes.minutes

        (time_str >= day_start_hm) && (end_time.strftime('%H:%M') <= day_end_hm)
      end

      def prepare_occupied_slots
        @occupied_slots_hash = @dates.each_with_object({}) do |date, hash|
          hash[date] = {}
        end

        fetch_reservations_for_week.each do |res|
          date = res.start_at.to_date
          next unless @occupied_slots_hash.key?(date)

          mark_slots_as_occupied(date, res)
        end
      end

      def mark_slots_as_occupied(date, reservation)
        start_slot = slot_for_time(reservation.start_at)
        end_slot = slot_for_time(reservation.end_at)

        (start_slot...end_slot).each do |slot|
          @occupied_slots_hash[date][slot] = true
        end
      end

      def fetch_reservations_for_week
        Reservation.where(
          stylist_id: @stylist.id,
          start_at: @dates.first.beginning_of_day..@dates.last.end_of_day,
          status: [:before_visit, :paid]
        )
      end

      def build_time_slots_for_week(_dates)
        earliest_start = @wh_non_holiday.map(&:start_time).compact_blank.min
        latest_end = @wh_non_holiday.map(&:end_time).compact_blank.max

        return [] if earliest_start.blank? || latest_end.blank?

        slots = []
        current_time = earliest_start
        while current_time < latest_end
          slots << current_time.strftime('%H:%M')
          current_time += 30.minutes
        end
        slots
      end

      def slot_for_time(time)
        (time.hour * 2) + (time.min >= 30 ? 1 : 0)
      end

      def within_reservation_limits?(limit_obj, date, slot, needed_slots)
        return false unless limit_obj

        (0...needed_slots).all? do |i|
          current_slot = slot + i
          current_limit = @reservation_limits_hash[date][current_slot]
          next false unless current_limit

          current_count = @reservation_counts[date][current_slot].to_i
          (current_count + 1) <= current_limit.max_reservations
        end
      end
    end
  end
end
