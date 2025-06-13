# frozen_string_literal: true

module Customers
  module Stylists
    # rubocop:disable Metrics/ClassLength
    class WeekliesController < Customers::ApplicationController
      before_action :ensure_customer_role
      before_action :set_stylist
      before_action :set_selected_menus
      before_action :set_dates_and_time_slots
      before_action :load_schedule_data

      helper_method :within_reservation_limits?, :total_duration, :within_working_hours?

      def index
        all_stylist_menus = @stylist.menus
        @show_reservation_symbol_guide = if all_stylist_menus.present?
                                           all_stylist_menus.none? { |menu| menu.duration <= 30 && menu.is_active }
                                         else
                                           false
                                         end

        @time_slots = build_time_slots_for_week(@dates)
      end

      private

      def set_stylist
        @stylist = User.find(params[:stylist_id])
        redirect_to customers_dashboard_path unless @stylist.stylist?
      end

      def set_selected_menus
        @selected_menu_ids = params[:menu_ids] || []
        @selected_menus = @stylist.menus.where(id: @selected_menu_ids)
      end

      def set_dates_and_time_slots
        target_date = if params[:start_date].present?
                        Date.parse(params[:start_date])
                      else
                        Date.current
                      end
        @start_date = [target_date, Date.current].max

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
      end

      def fetch_working_hours
        @wh_list = @stylist.working_hours.where(target_date: @dates).order(:start_time)
      end

      def fetch_holidays
        holiday_records = @stylist.holidays.where(target_date: @dates, is_holiday: true)
        @holiday_days = holiday_records.pluck(:target_date).to_set
      end

      def filter_non_holiday_working_hours
        @wh_non_holiday = @wh_list.reject { |wh| @holiday_days.include?(wh.target_date) }
      end

      def build_working_hours_hash
        @working_hours_hash = @wh_list.index_by(&:target_date)
      end

      def build_reservation_limits_hash
        limits = @stylist.reservation_limits.where(target_date: @dates)
        @reservation_limits_hash = @dates.index_with do |_date|
          {}
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
        @stylist.stylist_reservations.where(
          start_at: date.all_day,
          status: %i[before_visit paid]
        )
      end

      def set_can_go_previous
        @can_go_previous = @start_date > Date.current
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

      # rubocop:disable Metrics/AbcSize
      def build_time_slots_for_week(_dates)
        valid_working_hours = @wh_non_holiday.reject do |wh|
          wh.start_time.hour.zero? && wh.end_time.hour.zero?
        end

        if valid_working_hours.empty?
          earliest_start = Time.zone.parse(WorkingHour::DEFAULT_START_TIME)
          latest_end = Time.zone.parse(WorkingHour::DEFAULT_END_TIME)
        else
          earliest_start = valid_working_hours.map(&:start_time).min
          latest_end = valid_working_hours.map(&:end_time).max
        end

        slots = []
        current_time = earliest_start
        while current_time < latest_end
          slots << current_time.strftime('%H:%M')
          current_time += 30.minutes
        end
        slots
      end
      # rubocop:enable Metrics/AbcSize

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
    # rubocop:enable Metrics/ClassLength
  end
end
