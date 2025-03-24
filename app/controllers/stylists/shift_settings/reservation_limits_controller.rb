# frozen_string_literal: true

module Stylists
  module ShiftSettings
    class ReservationLimitsController < StylistsController
      before_action -> { ensure_role(:stylist) }

      def create
        limit_params = params.require(:reservation_limit).permit(:max_reservations)

        limit = ReservationLimit.find_or_initialize_by(stylist_id: current_user.id, target_date: nil)

        limit.max_reservations = limit_params[:max_reservations].to_i
        limit.save!

        redirect_to stylists_shift_settings_path,
          notice: I18n.t('stylists.shift_settings.reservation_limits.create_success')
      end
    end
  end
end
