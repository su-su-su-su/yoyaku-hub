# frozen_string_literal: true

module Stylists
  class ReservationsController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }
    before_action :set_reservation, only: %i[show edit update cancel]
    before_action :load_time_options, only: %i[edit update]
    before_action :load_active_menus, only: %i[edit update]

    def show; end

    def cancel
      @reservation.canceled!
      redirect_to stylists_schedules_path(date: @reservation.start_at.to_date), notice: t('stylists.reservations.cancelled')
    end

    def edit; end

    def update
      if @reservation.update(reservation_params)
        redirect_to stylists_reservation_path(date: @reservation.start_at.to_date), notice: t('stylists.reservations.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def update_time_options
      reservation_date = Reservation.safe_parse_date(
        params[:start_date_str],
        default: Time.zone.today
      )

      stylist_id = current_user.id
      @time_options = WorkingHour.time_options_for(stylist_id, reservation_date)

      render partial: 'time_select', locals: { f: nil, time_options: @time_options, selected_time: nil }
    end

    private

    def set_reservation
      @reservation = current_user.stylist_reservations.find(params[:id])
    end

    def reservation_params
      params.require(:reservation).permit(:start_date_str, :start_time_str, :custom_duration, menu_ids: [])
    end

    def load_time_options
      reservation_date = Reservation.safe_parse_date(
        params.dig(:reservation, :start_date_str),
        default: @reservation&.start_at&.to_date || Time.zone.today
      )

      stylist_id = current_user.id
      @time_options = WorkingHour.time_options_for(stylist_id, reservation_date)
    end

    def load_active_menus
      @active_menus = current_user.menus.where(is_active: true)
    end
  end
end
