# frozen_string_literal: true

module Stylists
  class ShiftSettingsController < StylistsController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }
    before_action :set_date_info, only: %i[index]
    before_action :ensure_profile_complete

    def index
      @weekday_hours = WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 1))
      @saturday_hours = WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 6))
      @sunday_hours = WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 0))
      @holiday_hours = WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 7))

      @weekday_start_str = @weekday_hours[:start]
      @weekday_end_str = @weekday_hours[:end]
      @saturday_start_str = @saturday_hours[:start]
      @saturday_end_str = @saturday_hours[:end]
      @sunday_start_str = @sunday_hours[:start]
      @sunday_end_str = @sunday_hours[:end]
      @holiday_start_str = @holiday_hours[:start]
      @holiday_end_str = @holiday_hours[:end]

      @chosen_wdays = current_user.holidays.where(target_date: nil).where.not(day_of_week: nil).pluck(:day_of_week)
      @current_limit = current_user.reservation_limits.find_by(target_date: nil)

      @is_this_month_configured = month_configured?(@this_month_year, @this_month)
      @is_next_month_configured = month_configured?(@next_month_year, @next_month)
      @is_next_next_month_configured = month_configured?(@next_next_month_year, @next_next_month)

      @time_options = WorkingHour.full_time_options
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
        @holidays_for_month[date] = current_user.holiday?(date)
      end

      @reservation_limits_for_month = {}
      (@start_date..@start_date.end_of_month).each do |date|
        @reservation_limits_for_month[date] = current_user.reservation_limit_for(date)
      end

      @time_options = WorkingHour.full_time_options
    end

    def create
      shift_data_params = params[:shift_data] || {}

      shift_data_params.each_value do |day_values|
        date_str = day_values[:date]
        date = begin
          Date.parse(date_str)
        rescue StandardError
          nil
        end
        is_holiday = (day_values[:is_holiday] == '1')

        start_str = day_values[:start_time].presence || WorkingHour::DEFAULT_START_TIME
        end_str = day_values[:end_time].presence || WorkingHour::DEFAULT_END_TIME
        max_res_str = day_values[:max_reservations].presence || '2'

        if is_holiday
          start_str = '00:00'
          end_str = '00:00'
          max_res_str = '0'
        end

        start_time_obj = Time.zone.parse(start_str)
        end_time_obj = Time.zone.parse(end_str)

        if is_holiday
          holiday = Holiday.find_or_initialize_by(stylist_id: current_user.id, target_date: date)
          holiday.is_holiday = true
          holiday.save!
        else
          Holiday.where(stylist_id: current_user.id, target_date: date).destroy_all

          Holiday.find_or_create_by!(stylist_id: current_user.id, target_date: date, is_holiday: false)
        end

        wh = WorkingHour.find_or_initialize_by(
          stylist_id: current_user.id,
          target_date: date
        )
        wh.start_time = start_time_obj
        wh.end_time = end_time_obj
        wh.holiday_flag = is_holiday ? '1' : '0'
        wh.save!

        save_reservation_limits(date, start_time_obj, end_time_obj, max_res_str.to_i)
      end

      redirect_to stylists_shift_settings_path, notice: t('flash.batch_setting_success')
    end

    def update_defaults
      settings_params = default_settings_params
      save_default_working_hours(settings_params[:working_hour])
      save_default_holidays(settings_params[:holiday])
      save_default_reservation_limit(settings_params[:reservation_limit])
      redirect_to stylists_shift_settings_path, notice: t('stylists.shift_settings.defaults.update_success')
    end

    private

    def set_date_info
      today = Time.zone.today
      @this_month_year = today.year
      @this_month = today.month
      next_month_date = today.next_month
      @next_month_year = next_month_date.year
      @next_month = next_month_date.month
      next_next_month_date = next_month_date.next_month
      @next_next_month_year = next_next_month_date.year
      @next_next_month = next_next_month_date.month
    end

    def save_reservation_limits(date, start_time_obj, end_time_obj, max_reservations)
      rl_day = ReservationLimit.find_or_initialize_by(
        stylist_id: current_user.id,
        target_date: date,
        time_slot: nil
      )
      rl_day.max_reservations = max_reservations
      rl_day.save!

      start_slot = (start_time_obj.hour * 2) + (start_time_obj.min >= 30 ? 1 : 0)
      end_slot = (end_time_obj.hour * 2) + (end_time_obj.min >= 30 ? 1 : 0)

      (start_slot...end_slot).each do |slot|
        rl_slot = ReservationLimit.find_or_initialize_by(
          stylist_id: current_user.id,
          target_date: date,
          time_slot: slot
        )
        rl_slot.max_reservations = max_reservations
        rl_slot.save!
      end
    end

    def month_configured?(year, month)
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month

      working_hour_exists = WorkingHour.exists?(stylist_id: current_user.id, target_date: start_date..end_date)
      holiday_exists = Holiday.exists?(stylist_id: current_user.id, target_date: start_date..end_date)
      reservation_limit_exist = ReservationLimit.exists?(stylist_id: current_user.id,
        target_date: start_date..end_date)
      working_hour_exists || holiday_exists || reservation_limit_exist
    end

    def ensure_profile_complete
      return if current_user.profile_complete?

      redirect_to edit_stylists_profile_path,
        alert: t('stylists.profiles.incomplete_profile')
    end

    def default_settings_params
      params.require(:default_settings).permit(
        working_hour: %i[weekday_start_time weekday_end_time saturday_start_time saturday_end_time
                         sunday_start_time sunday_end_time holiday_start_time holiday_end_time],
        holiday: [day_of_weeks: []],
        reservation_limit: [:max_reservations]
      )
    end

    def save_default_working_hours(working_hour_params)
      return unless working_hour_params

      weekday_start = Time.zone.parse(working_hour_params[:weekday_start_time])
      weekday_end = Time.zone.parse(working_hour_params[:weekday_end_time])
      saturday_start = Time.zone.parse(working_hour_params[:saturday_start_time])
      saturday_end = Time.zone.parse(working_hour_params[:saturday_end_time])
      sunday_start = Time.zone.parse(working_hour_params[:sunday_start_time])
      sunday_end = Time.zone.parse(working_hour_params[:sunday_end_time])
      holiday_start = Time.zone.parse(working_hour_params[:holiday_start_time])
      holiday_end = Time.zone.parse(working_hour_params[:holiday_end_time])

      (1..5).each do |wday|
        weekday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: wday,
          target_date: nil)
        weekday_working_hour.start_time = weekday_start
        weekday_working_hour.end_time = weekday_end
        weekday_working_hour.save!
      end

      saturday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 6,
        target_date: nil)
      saturday_working_hour.start_time = saturday_start
      saturday_working_hour.end_time = saturday_end
      saturday_working_hour.save!

      sunday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 0,
        target_date: nil)
      sunday_working_hour.start_time = sunday_start
      sunday_working_hour.end_time = sunday_end
      sunday_working_hour.save!

      holiday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 7,
        target_date: nil)
      holiday_working_hour.start_time = holiday_start
      holiday_working_hour.end_time = holiday_end
      holiday_working_hour.save!
    end

    def save_default_holidays(holiday_params)
      return unless holiday_params

      chosen_wdays = holiday_params[:day_of_weeks].compact_blank.map(&:to_i)
      existing_defaults = Holiday.where(stylist_id: current_user.id, target_date: nil).where.not(day_of_week: nil)

      if chosen_wdays.empty?
        existing_defaults.destroy_all
      else
        existing_defaults.where.not(day_of_week: chosen_wdays).destroy_all

        chosen_wdays.each do |wday|
          holiday = Holiday.find_or_initialize_by(stylist_id: current_user.id, day_of_week: wday, target_date: nil)
          holiday.save! unless holiday.persisted?
        end
      end
    end

    def save_default_reservation_limit(limit_params)
      return unless limit_params

      limit = ReservationLimit.find_or_initialize_by(stylist_id: current_user.id, target_date: nil, time_slot: nil)

      limit.max_reservations = limit_params[:max_reservations].to_i
      limit.save!
    end
  end
end
