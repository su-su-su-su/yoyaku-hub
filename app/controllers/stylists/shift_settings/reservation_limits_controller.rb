# frozen_string_literal: true

module Stylists
  module ShiftSettings
    class ReservationLimitsController < StylistsController
      before_action :authenticate_user!
      before_action -> { ensure_role(:stylist) }

      def update
        date = Date.parse(params[:date])
        slot_idx = params[:slot].to_i
        direction = params[:direction]

        limit = ReservationLimit.find_or_initialize_by(
          stylist_id: current_user.id,
          target_date: date,
          time_slot: slot_idx
        )

        if limit.new_record?
          global_default_limit = ReservationLimit.find_by(stylist_id: current_user.id, target_date: nil, time_slot: nil)

          initial_max_reservations = 0
          if global_default_limit&.max_reservations.present?
            initial_max_reservations = global_default_limit.max_reservations
          end
          limit.max_reservations = initial_max_reservations
        end

        current_max = limit.max_reservations.to_i

        max_upper_bound = 2
        min_lower_bound = 0

        if direction == 'up'
          limit.max_reservations = [current_max + 1, max_upper_bound].min
        elsif direction == 'down'
          limit.max_reservations = [current_max - 1, min_lower_bound].max
        end

        limit.save!
        head :no_content
      end
    end
  end
end
