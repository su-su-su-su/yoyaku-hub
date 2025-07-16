# frozen_string_literal: true

module Stylists
  class SchedulesController < Stylists::ApplicationController
    before_action :set_date, only: %i[show reservation_limits]
    before_action :set_stylist, only: %i[show weekly]
    before_action :set_weekly_dates, only: %i[weekly]
    helper_method :to_slot_index

    def show
      @schedule = Schedule.new(@stylist.id, @date)
    end

    def weekly
      @schedules = @dates.map { |date| Schedule.new(@stylist.id, date) }
      @time_slots = build_time_slots_for_week
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

    def set_weekly_dates
      target_date = if params[:start_date].present?
                      Date.parse(params[:start_date])
                    else
                      Date.current
                    end
      @start_date = target_date
      @dates = (@start_date..(@start_date + 6.days)).to_a
    end

    def build_time_slots_for_week
      valid_working_hours = collect_valid_working_hours
      earliest_start, latest_end = determine_time_range(valid_working_hours)
      generate_time_slots(earliest_start, latest_end)
    end

    def collect_valid_working_hours
      working_hours = @dates.flat_map do |date|
        working_hour = @stylist.working_hour_for_target_date(date)
        next [] if working_hour.nil? || @stylist.holiday?(date)

        working_hour
      end.compact

      working_hours.reject { |wh| wh.start_time.hour.zero? && wh.end_time.hour.zero? }
    end

    def determine_time_range(valid_working_hours)
      if valid_working_hours.empty?
        [Time.zone.parse(WorkingHour::DEFAULT_START_TIME), Time.zone.parse(WorkingHour::DEFAULT_END_TIME)]
      else
        [valid_working_hours.map(&:start_time).min, valid_working_hours.map(&:end_time).max]
      end
    end

    def generate_time_slots(earliest_start, latest_end)
      slots = []
      current_time = earliest_start
      while current_time < latest_end
        slots << current_time.strftime('%H:%M')
        current_time += 30.minutes
      end
      slots
    end

    def to_slot_index(time_or_str)
      Schedule.to_slot_index(time_or_str)
    end
  end
end
