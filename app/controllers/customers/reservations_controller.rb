# frozen_string_literal: true

module Customers
  class ReservationsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_customer_role
    before_action :set_reservation, only: %i[show cancel]
    before_action :set_reservation_form_data, only: %i[new create]

    def index
      user = current_user

      @upcoming_reservations = user.reservations
        .where(start_at: Time.zone.now..)
        .where.not(status: %i[canceled no_show])
        .order(:start_at)

      @past_reservations = user.reservations
        .where(start_at: ..Time.zone.now)
        .or(user.reservations.where(status: :canceled))
        .order(start_at: :desc)
    end

    def show
      load_reservation_details
    end

    def new
      @user = current_user
      parse_start_time_for_display
    end

    def create
      @user = current_user

      @reservation = build_reservation

      if @reservation.save
        redirect_to customers_reservation_path(@reservation), notice: t('flash.reservation_confirmed')
      else
        flash.now[:alert] = t('flash.reservation_failed')
        render :new
      end
    end

    def cancel
      @reservation.canceled!
      redirect_to customers_reservations_path(date: @reservation.start_at.to_date),
        notice: t('stylists.reservations.cancelled')
    end

    private

    def set_reservation
      @reservation = current_user.reservations.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to customers_reservations_path, alert: t('flash.reservation_not_found')
    end

    def set_reservation_form_data
      @stylist_id = params[:stylist_id]
      @date = params[:date]
      @time_str = params[:time_str]
      @menu_ids = params[:menu_ids]
      @stylist = User.find(@stylist_id)
      @menus = Menu.where(id: @menu_ids).to_a
      calculate_totals
    end

    def parse_start_time_for_display
      date_time_str = "#{@date} #{@time_str}"
      @start_time_obj = begin
        Time.zone.parse(date_time_str)
      rescue StandardError
        nil
      end
    end

    def calculate_totals
      @total_duration = @menus.sum(&:duration)
      @total_price    = @menus.sum(&:price)
    end

    def load_reservation_details
      @stylist = @reservation.stylist
      @menus   = @reservation.menus
      calculate_totals
    end

    def build_reservation
      reservation = Reservation.new(
        customer: @user,
        stylist: @stylist,
        start_date_str: @date,
        start_time_str: @time_str
      )
      reservation.menu_ids = @menu_ids
      reservation
    end
  end
end
