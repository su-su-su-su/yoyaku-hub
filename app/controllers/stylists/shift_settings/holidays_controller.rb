# frozen_string_literal: true

module Stylists
  module ShiftSettings
    class HolidaysController < StylistsController
      before_action -> { ensure_role(:stylist) }

      def create
        holiday_params = params.require(:holiday).permit(day_of_weeks: [])
        chosen_wdays = holiday_params[:day_of_weeks].compact_blank.map(&:to_i)

        existing = Holiday.where(stylist_id: current_user.id)

        if chosen_wdays.empty?
          existing.destroy_all
        else
          existing.where.not(day_of_week: chosen_wdays).destroy_all

          chosen_wdays.each do |wday|
            hol = Holiday.find_or_initialize_by(stylist_id: current_user.id, day_of_week: wday)
            hol.save! unless hol.persisted?
          end
        end

        redirect_to stylists_shift_settings_path, notice: t('stylists.shift_settings.holidays.create_success')
      end
    end
  end
end
