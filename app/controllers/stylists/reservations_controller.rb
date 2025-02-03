# frozen_string_literal: true

module Stylists
  class ReservationsController < ApplicationController
    def show
      @reservation = Reservation.find(params[:id])
    end
  end
end
