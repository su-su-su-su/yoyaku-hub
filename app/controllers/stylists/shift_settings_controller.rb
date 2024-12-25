# frozen_string_literal: true

module Stylists
  class ShiftSettingsController < StylistsController
    before_action :authenticate_user!
    before_action :set_time_options, only: [:index, :show]

    def index
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

      holiday_wh = WorkingHour.find_by(stylist_id: current_user.id, day_of_week: 7)
      if holiday_wh
        @holiday_start_str = holiday_wh.start_time.strftime('%H:%M')
        @holiday_end_str = holiday_wh.end_time.strftime('%H:%M')
      else
        @holiday_start_str = '09:00'
        @holiday_end_str = '18:00'
      end

      @chosen_wdays = Holiday.where(stylist_id: current_user.id).pluck(:day_of_week)

      @current_limit = ReservationLimit.find_by(stylist_id: current_user.id)

      today = Date.today
      @this_month_year = today.year
      @this_month = today.month

      next_month_date = today.next_month
      @next_month_year = next_month_date.year
      @next_month = next_month_date.month

      next_next_month_date = next_month_date.next_month
      @next_next_month_year = next_next_month_date.year
      @next_next_month = next_next_month_date.month

    end

    def show
      @year = params[:year].to_i
      @month = params[:month].to_i
      @start_date = Date.new(@year, @month, 1)

      @working_hours_for_month = {}
      (@start_date..@start_date.end_of_month).each do |date|
        @working_hours_for_month[date] = WorkingHour.default_for(current_user.id, date)
      end

      @holidays_for_month = {}
      (@start_date..@start_date.end_of_month).each do |date|
        holiday = Holiday.default_for(current_user.id, date)
        @holidays_for_month[date] = holiday.present?
      end

      @reservation_limits_for_month = {}
      (@start_date..@start_date.end_of_month).each do |date|
        @reservation_limits_for_month[date] = ReservationLimit.default_for(current_user.id, date)
      end
    end

    def create
      shift_data_params = params[:shift_data] || {}
    
      shift_data_params.each do |day_key, day_values|
        date_str = day_values[:date]
        date = Date.parse(date_str) rescue nil
        is_holiday = (day_values[:is_holiday] == "1")
    
        start_str = day_values[:start_time].presence || "09:00"
        end_str   = day_values[:end_time].presence   || "18:00"
        max_res_str = day_values[:max_reservations].presence || "2"
    
        if is_holiday
          start_str = "00:00"
          end_str   = "00:00"
          max_res_str = "0"
        end
    
        start_time_obj = Time.zone.parse(start_str)
        end_time_obj   = Time.zone.parse(end_str)
    
        if is_holiday
          Holiday.find_or_create_by!(stylist_id: current_user.id, target_date: date)
        else
          Holiday.where(stylist_id: current_user.id, target_date: date).destroy_all
        end
    
        wh = WorkingHour.find_or_initialize_by(
          stylist_id: current_user.id,
          target_date: date
        )
        wh.start_time = start_time_obj
        wh.end_time   = end_time_obj
        wh.holiday_flag = is_holiday ? "1" : "0"
        wh.save!
    
        rl = ReservationLimit.find_or_initialize_by(stylist_id: current_user.id, target_date: date)
        rl.max_reservations = max_res_str.to_i
        rl.save!
      end
    
      redirect_to stylists_shift_settings_path, notice: "一括設定しました"
    end

    private

      def set_time_options
        @time_options = (0..47).map do |i|
          hour = i / 2
          minute = (i % 2) * 30
          time_str = format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
          [time_str, time_str]
        end
      end
  end
end
