# frozen_string_literal: true

module Stylists
  class ReservationsController < ApplicationController
    before_action :set_reservation, only: %i[edit update]
    before_action :prepare_time_options, only: %i[edit update]
    def show
      @reservation = Reservation.find(params[:id])
    end

    def cancel
      @reservation = Reservation.find(params[:id])
      @reservation.canceled!
      redirect_to stylists_schedules_path(date: @reservation.start_at.to_date),
                  notice: I18n.t('flash.reservation_cancelled')
    end

    def edit; end

    def update
      if @reservation.update(reservation_params)
        redirect_to stylists_reservation_path(date: @reservation.start_at.to_date), notice: '予約が正常に更新されました。'
      else
        render :edit
      end
    end

    def update_time_options
      reservation_date = params[:start_date_str].present? ? Date.parse(params[:start_date_str]) : Time.zone.today
      stylist_id = params[:stylist_id]

      @working_hour = WorkingHour.date_only_for(stylist_id, reservation_date)
      if @working_hour.present?
        start_time = @working_hour.start_time
        end_time   = @working_hour.end_time
      else
        start_time = Time.zone.parse('10:00')
        end_time   = Time.zone.parse('20:00')
      end

      @time_options = []
      current_time = start_time
      while current_time <= end_time
        formatted = current_time.strftime('%H:%M')
        @time_options << [formatted, formatted]
        current_time += 30.minutes
      end

      render partial: 'time_select', locals: { f: nil, time_options: @time_options, selected_time: nil }
    end

    private

    def set_reservation
      @reservation = Reservation.find(params[:id])
    end

    def reservation_params
      params.require(:reservation).permit(:start_date_str, :start_time_str)
    end

    def prepare_time_options
      reservation_date =
        if params.dig(:reservation, :start_date_str).present?
          Date.parse(params[:reservation][:start_date_str])
        elsif @reservation.start_at.present?
          @reservation.start_at.to_date
        else
          Time.zone.today
        end

      stylist_id = @reservation.stylist_id
      @working_hour = WorkingHour.date_only_for(stylist_id, reservation_date)

      if @working_hour.present?
        start_time = @working_hour.start_time
        end_time   = @working_hour.end_time
      else
        start_time = Time.zone.parse('10:00')
        end_time   = Time.zone.parse('20:00')
      end

      @time_options = []
      current_time = start_time
      while current_time <= end_time
        formatted = current_time.strftime('%H:%M')
        @time_options << [formatted, formatted]
        current_time += 30.minutes
      end
    end
  end
end
