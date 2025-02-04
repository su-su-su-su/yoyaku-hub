# frozen_string_literal: true

module Stylists
  class SchedulesController < ApplicationController
    helper_method :to_slot_index

    def show
      @date = begin
        Date.parse(params[:date])
      rescue StandardError
        Date.current
      end
    
      @stylist = current_user
      @is_holiday = Holiday.default_for(@stylist.id, @date)
      set_working_hour_and_time_slots(@stylist.id, @date)
      @reservation_counts = slotwise_reservation_counts(@stylist.id, @date)
      @reservation_limits = slotwise_reservation_limits(@stylist.id, @date)
      
      @slotwise_reservations = slotwise_reservations_map(@stylist.id, @date)
    end
    
    

    def reservation_limits
      date_str   = params[:date]
      slot_str   = params[:slot]
      direction  = params[:direction]
      
      @date = Date.parse(date_str) rescue Date.current 
      slot_idx = slot_str.to_i
    
      set_working_hour_and_time_slots(current_user.id, @date)

      limit = ReservationLimit.find_or_initialize_by(
        stylist_id: current_user.id,
        target_date: @date,
        time_slot: slot_idx
      )
      limit.max_reservations ||= 0
    
      if direction == "up"
        limit.max_reservations += 1
      elsif direction == "down" && limit.max_reservations > 0
        limit.max_reservations -= 1
      end
      limit.save!
 
      @reservation_counts = slotwise_reservation_counts(current_user.id, @date)
      @reservation_limits = slotwise_reservation_limits(current_user.id, @date)
    
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("slot-limit-#{slot_idx}", partial: 'slot_limit', locals: { slot_idx: slot_idx })
        }
        format.html {
          render partial: 'slot_limit', locals: { slot_idx: slot_idx }
        }
      end
    end

    private

    def set_working_hour_and_time_slots(stylist_id, date)
      @is_holiday = Holiday.default_for(stylist_id, date)
      if @is_holiday
        @time_slots = []
        @working_hour = nil
        return
      end
    
      @working_hour = WorkingHour.date_only_for(stylist_id, date)
      if @working_hour.nil?
        @time_slots = []
      else
        start_str = @working_hour.start_time.strftime('%H:%M')
        end_str   = @working_hour.end_time.strftime('%H:%M')
        @time_slots = generate_time_slots(start_str, end_str, 30)
      end
    end

    def generate_time_slots(start_str, end_str, step)
      start_time = Time.zone.parse(start_str)
      end_time   = Time.zone.parse(end_str)
      slots = []
      while start_time <= end_time
        slots << start_time.strftime('%H:%M')
        start_time += step.minutes
      end
      slots
    end

    def parse_date(date_str)
      Date.parse(date_str)
    rescue StandardError
      nil
    end

   def slotwise_reservation_counts(stylist_id, date)
     reservations = Reservation.where(stylist_id: stylist_id)
       .where(start_at: date.beginning_of_day..date.end_of_day)
       .where.not(status: [:canceled, :no_show])
     counts = Hash.new(0)
     reservations.each do |res|
       start_slot = to_slot_index(res.start_at)
       end_slot   = to_slot_index(res.end_at)
       (start_slot...end_slot).each do |slot_idx|
         counts[slot_idx] += 1
       end
     end
     counts
   end


    def slotwise_reservation_limits(stylist_id, date)
      limits = Hash.new(0)
      daily_limits = ReservationLimit.where(stylist_id: stylist_id, target_date: date)
      daily_limits.each do |lim|
        slot = lim.time_slot
        limits[slot] = lim.max_reservations
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
      slot_idx = (h * 2) + (m >= 30 ? 1 : 0)
      slot_idx
    end
    

    def slotwise_reservations_map(stylist_id, date)
      reservations = Reservation.where(stylist_id: stylist_id)
                              .where(status: [:before_visit, :paid])
                              .where("start_at >= ? AND end_at <= ?",
                                     date.beginning_of_day.in_time_zone, date.end_of_day.in_time_zone)
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
