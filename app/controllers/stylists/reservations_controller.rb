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
  end
end
