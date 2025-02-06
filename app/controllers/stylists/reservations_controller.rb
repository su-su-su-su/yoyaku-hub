# frozen_string_literal: true

module Stylists
  class ReservationsController < ApplicationController
    def show
      @reservation = Reservation.find(params[:id])
    end

    def cancel
      @reservation = Reservation.find(params[:id])
      @reservation.canceled!
      redirect_to stylists_schedules_path(date: @reservation.start_at.to_date),
                  notice: I18n.t('flash.reservation_cancelled')
    end

    def edit
      @reservation = Reservation.find(params[:id])
      reservation_date = @reservation.start_at.present? ? @reservation.start_at.to_date : Date.today
      stylist_id = @reservation.stylist_id
      @working_hour = WorkingHour.date_only_for(stylist_id, reservation_date)

      if @working_hour.present?
        start_time = @working_hour.start_time
        end_time   = @working_hour.end_time
      else
        start_time = Time.zone.parse("10:00")
        end_time   = Time.zone.parse("20:00")
      end

      @time_options = []
      current_time = start_time
      while current_time <= end_time
        formatted = current_time.strftime("%H:%M")
        @time_options << [formatted, formatted]
        current_time += 30.minutes
      end
    end

    def update
      @reservation = Reservation.find(params[:id])
    end

    def update_time_options
      reservation_date = params[:start_date_str].present? ? Date.parse(params[:start_date_str]) : Date.today
      stylist_id = params[:stylist_id]

      @working_hour = WorkingHour.date_only_for(stylist_id, reservation_date)
      if @working_hour.present?
        start_time = @working_hour.start_time
        end_time   = @working_hour.end_time
      else
        start_time = Time.zone.parse("10:00")
        end_time   = Time.zone.parse("20:00")
      end

      @time_options = []
      current_time = start_time
      while current_time <= end_time
        formatted = current_time.strftime("%H:%M")
        @time_options << [formatted, formatted]
        current_time += 30.minutes
      end

      render partial: "time_select", locals: { f: nil, time_options: @time_options, selected_time: nil }
    end
  end
end
