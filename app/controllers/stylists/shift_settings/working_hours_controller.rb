# frozen_string_literal: true

module Stylists
  module ShiftSettings
    class WorkingHoursController < StylistsController
      before_action -> { ensure_role(:stylist) }

      def create
        wh_params = params.require(:working_hour).permit(
          :weekday_start_time, :weekday_end_time,
          :saturday_start_time, :saturday_end_time,
          :sunday_start_time, :sunday_end_time,
          :holiday_start_time, :holiday_end_time
        )

        weekday_start = Time.zone.parse(wh_params[:weekday_start_time])
        weekday_end = Time.zone.parse(wh_params[:weekday_end_time])
        saturday_start = Time.zone.parse(wh_params[:saturday_start_time])
        saturday_end = Time.zone.parse(wh_params[:saturday_end_time])
        sunday_start = Time.zone.parse(wh_params[:sunday_start_time])
        sunday_end = Time.zone.parse(wh_params[:sunday_end_time])
        holiday_start = Time.zone.parse(wh_params[:holiday_start_time])
        holiday_end = Time.zone.parse(wh_params[:holiday_end_time])

        (1..5).each do |wday|
          wh = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: wday)
          wh.start_time = weekday_start
          wh.end_time = weekday_end
          wh.save!
        end

        wh_sat = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 6)
        wh_sat.start_time = saturday_start
        wh_sat.end_time = saturday_end
        wh_sat.save!

        wh_sun = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 0)
        wh_sun.start_time = sunday_start
        wh_sun.end_time = sunday_end
        wh_sun.save!

        wh_holiday = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 7)
        wh_holiday.start_time = holiday_start
        wh_holiday.end_time = holiday_end
        wh_holiday.save!

        redirect_to stylists_shift_settings_path, notice: t('stylists.shift_settings.working_hours.create_success')
      end
    end
  end
end
