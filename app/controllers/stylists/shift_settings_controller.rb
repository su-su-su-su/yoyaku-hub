# frozen_string_literal: true

module Stylists
  # rubocop:disable Metrics/ClassLength
  class ShiftSettingsController < Stylists::ApplicationController
    before_action :ensure_profile_complete

    # rubocop:disable Metrics/AbcSize
    def index
      @default_working_hours = {
        weekday: WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 1)),
        saturday: WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 6)),
        sunday: WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 0)),
        holiday: WorkingHour.formatted_hours(current_user.working_hours.find_by(day_of_week: 7))
      }

      @default_holidays = current_user.holidays.defaults
      @default_reservation_limit = current_user.reservation_limits.defaults.first

      today = Time.zone.today
      this_month_date = today
      next_month_date = today.next_month
      next_next_month_date = today.next_month.next_month

      @monthly_configs = [
        { date: this_month_date, configured: month_configured?(this_month_date.year, this_month_date.month) },
        { date: next_month_date, configured: month_configured?(next_month_date.year, next_month_date.month) },
        { date: next_next_month_date,
          configured: month_configured?(next_next_month_date.year, next_next_month_date.month) }
      ]

      @time_options = WorkingHour.full_time_options
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def show
      @year = params[:year].to_i
      @month = params[:month].to_i
      @start_date = Date.new(@year, @month, 1)

      @working_hours_for_month = {}
      (@start_date..@start_date.end_of_month).each do |date|
        @working_hours_for_month[date] = current_user.working_hour_for(date)
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
      @month_already_configured = month_configured?(@year, @month)
      @existing_reservations = fetch_month_reservations(@year, @month)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength
    def create
      shift_data_params = params[:shift_data] || {}

      # rubocop:disable Metrics/BlockLength
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
          holiday = current_user.holidays.find_or_initialize_by(target_date: date)
          holiday.is_holiday = true
          holiday.save!
        else
          current_user.holidays.where(target_date: date).destroy_all

          current_user.holidays.find_or_create_by!(target_date: date, is_holiday: false)
        end

        wh = current_user.working_hours.find_or_initialize_by(
          target_date: date
        )
        wh.start_time = start_time_obj
        wh.end_time = end_time_obj
        wh.holiday_flag = is_holiday ? '1' : '0'
        wh.save!

        save_reservation_limits(date, start_time_obj, end_time_obj, max_res_str.to_i)
      end
      # rubocop:enable Metrics/BlockLength

      redirect_with_toast stylists_shift_settings_path, t('flash.batch_setting_success'), type: :success
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength

    def update_defaults
      settings_params = default_settings_params
      save_default_working_hours(settings_params[:working_hour])
      save_default_holidays(settings_params[:holiday])
      save_default_reservation_limit(settings_params[:reservation_limit])
      redirect_with_toast stylists_shift_settings_path, t('stylists.shift_settings.defaults.update_success'),
        type: :success
    end

    private

    # rubocop:disable Metrics/AbcSize
    def save_reservation_limits(date, start_time_obj, end_time_obj, max_reservations)
      rl_day = current_user.reservation_limits.find_or_initialize_by(
        target_date: date,
        time_slot: nil
      )
      rl_day.max_reservations = max_reservations
      rl_day.save!

      start_slot = (start_time_obj.hour * 2) + (start_time_obj.min >= 30 ? 1 : 0)
      end_slot = (end_time_obj.hour * 2) + (end_time_obj.min >= 30 ? 1 : 0)

      (start_slot...end_slot).each do |slot|
        rl_slot = current_user.reservation_limits.find_or_initialize_by(
          target_date: date,
          time_slot: slot
        )
        rl_slot.max_reservations = max_reservations
        rl_slot.save!
      end
    end
    # rubocop:enable Metrics/AbcSize

    def month_configured?(year, month)
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month

      working_hour_exists = current_user.working_hours.exists?(target_date: start_date..end_date)
      holiday_exists = current_user.holidays.exists?(target_date: start_date..end_date)
      reservation_limit_exist = current_user.reservation_limits.exists?(target_date: start_date..end_date)
      working_hour_exists || holiday_exists || reservation_limit_exist
    end

    def ensure_profile_complete
      return if current_user.profile_complete?

      redirect_with_toast edit_stylists_profile_path,
        t('stylists.profiles.incomplete_profile'), type: :error
    end

    def default_settings_params
      params.require(:default_settings).permit(
        working_hour: %i[weekday_start_time weekday_end_time saturday_start_time saturday_end_time
                         sunday_start_time sunday_end_time holiday_start_time holiday_end_time],
        holiday: [day_of_weeks: []],
        reservation_limit: [:max_reservations]
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
        weekday_working_hour = current_user.working_hours.find_or_initialize_by(day_of_week: wday,
          target_date: nil)
        weekday_working_hour.start_time = weekday_start
        weekday_working_hour.end_time = weekday_end
        weekday_working_hour.save!
      end

      saturday_working_hour = current_user.working_hours.find_or_initialize_by(day_of_week: 6,
        target_date: nil)
      saturday_working_hour.start_time = saturday_start
      saturday_working_hour.end_time = saturday_end
      saturday_working_hour.save!

      sunday_working_hour = current_user.working_hours.find_or_initialize_by(day_of_week: 0,
        target_date: nil)
      sunday_working_hour.start_time = sunday_start
      sunday_working_hour.end_time = sunday_end
      sunday_working_hour.save!

      holiday_working_hour = current_user.working_hours.find_or_initialize_by(day_of_week: 7,
        target_date: nil)
      holiday_working_hour.start_time = holiday_start
      holiday_working_hour.end_time = holiday_end
      holiday_working_hour.save!
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize
    def save_default_holidays(holiday_params)
      return unless holiday_params

      chosen_wdays = holiday_params[:day_of_weeks].compact_blank.map(&:to_i)
      existing_defaults = current_user.holidays.where(target_date: nil).where.not(day_of_week: nil)

      if chosen_wdays.empty?
        existing_defaults.destroy_all
      else
        existing_defaults.where.not(day_of_week: chosen_wdays).destroy_all

        chosen_wdays.each do |wday|
          holiday = current_user.holidays.find_or_initialize_by(day_of_week: wday, target_date: nil)
          holiday.save! unless holiday.persisted?
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def save_default_reservation_limit(limit_params)
      return unless limit_params

      limit = current_user.reservation_limits.find_or_initialize_by(target_date: nil, time_slot: nil)

      limit.max_reservations = limit_params[:max_reservations].to_i
      limit.save!
    end

    def fetch_month_reservations(year, month)
      start_date = Date.new(year, month, 1)
      end_date = start_date.end_of_month

      reservations = current_user.stylist_reservations
                                 .where(status: %i[before_visit paid])
                                 .where(start_at: start_date.beginning_of_day..end_date.end_of_day)
                                 .includes(:customer)

      reservations.map do |reservation|
        {
          date: reservation.start_at.to_date.iso8601,
          start_time: reservation.start_at.strftime('%H:%M'),
          end_time: reservation.end_at.strftime('%H:%M'),
          customer_name: "#{reservation.customer.family_name} #{reservation.customer.given_name}"
        }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
