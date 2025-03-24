# frozen_string_literal: true

module Stylists
  module ShiftSettings
    class WorkingHoursController < StylistsController
      before_action -> { ensure_role(:stylist) }

      def create
        working_hour_params = params.require(:working_hour).permit(
          :weekday_start_time, :weekday_end_time,
          :saturday_start_time, :saturday_end_time,
          :sunday_start_time, :sunday_end_time,
          :holiday_start_time, :holiday_end_time
        )

        weekday_start = Time.zone.parse(working_hour_params[:weekday_start_time])
        weekday_end = Time.zone.parse(working_hour_params[:weekday_end_time])
        saturday_start = Time.zone.parse(working_hour_params[:saturday_start_time])
        saturday_end = Time.zone.parse(working_hour_params[:saturday_end_time])
        sunday_start = Time.zone.parse(working_hour_params[:sunday_start_time])
        sunday_end = Time.zone.parse(working_hour_params[:sunday_end_time])
        holiday_start = Time.zone.parse(working_hour_params[:holiday_start_time])
        holiday_end = Time.zone.parse(working_hour_params[:holiday_end_time])

        (1..5).each do |wday|
          weekday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: wday)
          weekday_working_hour.start_time = weekday_start
          weekday_working_hour.end_time = weekday_end
          weekday_working_hour.save!
        end

        saturday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 6)
        saturday_working_hour.start_time = saturday_start
        saturday_working_hour.end_time = saturday_end
        saturday_working_hour.save!

        sunday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 0)
        sunday_working_hour.start_time = sunday_start
        sunday_working_hour.end_time = sunday_end
        sunday_working_hour.save!

        holiday_working_hour = WorkingHour.find_or_initialize_by(stylist_id: current_user.id, day_of_week: 7)
        holiday_working_hour.start_time = holiday_start
        holiday_working_hour.end_time = holiday_end
        holiday_working_hour.save!

        redirect_to stylists_shift_settings_path, notice: t('stylists.shift_settings.working_hours.create_success')
      end
    end
  end
end
