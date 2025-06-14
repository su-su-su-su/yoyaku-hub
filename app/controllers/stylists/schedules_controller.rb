# frozen_string_literal: true

module Stylists
  class SchedulesController < Stylists::ApplicationController
    before_action :set_date, only: %i[show reservation_limits]
    before_action :set_stylist, only: %i[show]
    helper_method :to_slot_index

    def show
      @schedule = Schedule.new(@stylist.id, @date)
    end

    def reservation_limits
      slot_idx = params[:slot].to_i
      direction = params[:direction]
      stylist_id = current_user.id

      schedule = Schedule.new(stylist_id, @date)
      schedule.update_reservation_limit(slot_idx, direction)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('reservation-limits-row',
            partial: 'reservation_limits_row', locals: { schedule: schedule })
        end
        format.html do
          redirect_to stylists_schedules_path(date: @date.strftime('%Y-%m-%d'))
        end
      end
    end

    private

    def set_date
      @date = Schedule.safe_parse_date(params[:date])
    end

    def set_stylist
      @stylist = current_user
    end

    def to_slot_index(time_or_str)
      Schedule.to_slot_index(time_or_str)
    end
  end
end
