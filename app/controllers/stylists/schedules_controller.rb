# frozen_string_literal: true

module Stylists
  class SchedulesController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }
    before_action :set_date, only: %i[show reservation_limits]
    before_action :set_stylist, only: %i[show]
    helper_method :to_slot_index

    def show
      @is_holiday = Holiday.default_for(@stylist.id, @date)
      set_schedule_data(@stylist.id, @date)
    end

    def reservation_limits
      slot_idx = params[:slot].to_i
      direction = params[:direction]
      stylist_id = current_user.id

      update_reservation_limit(stylist_id, @date, slot_idx, direction)

      @is_holiday = Holiday.default_for(stylist_id, @date)
      set_working_hour_and_time_slots(stylist_id, @date)
      @reservation_counts = slotwise_reservation_counts(stylist_id, @date)
      @reservation_limits = slotwise_reservation_limits(stylist_id, date: @date)

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("reservation-limits-row",
            partial: 'reservation_limits_row', locals: { time_slots: @time_slots })
        }
        format.html {
          redirect_to stylists_schedules_path(date: @date.strftime("%Y-%m-%d"))
        }
      end
    end

    private

    def set_date
      @date = begin
        Date.parse(params[:date])
      rescue StandardError
        Date.current
      end
    end

    def set_stylist
      @stylist = current_user
    end

    def set_schedule_data(stylist_id, date)
      @is_holiday = Holiday.default_for(stylist_id, date)
      set_working_hour_and_time_slots(stylist_id, date)
      @reservation_counts = slotwise_reservation_counts(stylist_id, date)
      @reservation_limits = slotwise_reservation_limits(stylist_id, date: date)
      @slotwise_reservations = slotwise_reservations_map(stylist_id, date) if action_name == 'show'
    end

    def update_reservation_limit(stylist_id, date, slot_idx, direction)
      limit = ReservationLimit.find_or_initialize_by(
        stylist_id: stylist_id,
        target_date: date,
        time_slot: slot_idx
      )
      limit.max_reservations ||= 0

      case direction
      when "up"
        limit.max_reservations += 1
      when "down"
        limit.max_reservations -= 1 if limit.max_reservations > 0
      end

      limit.save
    end

    def set_working_hour_and_time_slots(stylist_id, date)
      if @is_holiday
        @time_slots = []
        @working_hour = nil
        return
      end

      @working_hour = WorkingHour.date_only_for(stylist_id, date)
      if @working_hour.nil?
        @time_slots = []
      else
        hours = WorkingHour.formatted_hours(@working_hour)
        @time_slots = WorkingHour.generate_time_options_between(
          Time.zone.parse(hours[:start]),
          Time.zone.parse(hours[:end])
        ).map(&:first)
      end
    end

    def slotwise_reservation_counts(stylist_id, date)
      reservations = Reservation.where(stylist_id: stylist_id)
        .where(start_at: date.beginning_of_day..date.end_of_day)
        .where.not(status: [:canceled, :no_show])

      counts = Hash.new(0)
      reservations.each do |res|
        start_slot = to_slot_index(res.start_at)
        end_slot = to_slot_index(res.end_at)
        (start_slot...end_slot).each do |slot_idx|
          counts[slot_idx] += 1
        end
      end
      counts
    end

    def slotwise_reservation_limits(stylist_id, date:)
      limits = Hash.new(0)
      ReservationLimit.where(stylist_id: stylist_id, target_date: date).each do |lim|
        limits[lim.time_slot] = lim.max_reservations
      end
      limits
    end

    def to_slot_index(time_or_str)
      case time_or_str
      when String
        h, m = time_or_str.split(':').map(&:to_i)
      when Time, ActiveSupport::TimeWithZone
        h = time_or_str.hour
        m = time_or_str.min
      else
        raise ArgumentError, "Unsupported type: #{time_or_str.class}"
      end
      (h * 2) + (m >= 30 ? 1 : 0)
    end

    def slotwise_reservations_map(stylist_id, date)
      reservations = Reservation.where(stylist_id: stylist_id)
        .where(status: [:before_visit, :paid])
        .where(
          "start_at >= ? AND end_at <= ?",
          date.beginning_of_day.in_time_zone,
          date.end_of_day.in_time_zone
        )
        .where.not(start_at: nil, end_at: nil)
        .includes(:menus, :customer)

      map = Hash.new { |h, k| h[k] = [] }

      reservations.each do |res|
        start_idx = to_slot_index(res.start_at)
        end_idx = to_slot_index(res.end_at)
        (start_idx...end_idx).each do |slot_idx|
          map[slot_idx] << res
        end
      end
      map
    end
  end
end
