# frozen_string_literal: true

module Customers
  class ReservationsController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:customer) }
    before_action :set_reservation, only: [:show]

    def index
      user = current_user
      @upcoming_reservations = user.reservations.where("start_at >= ?", Time.zone.now).where.not(status: [:canceled, :no_show]).order(:start_at)
      @past_reservations = user.reservations.where("(start_at < :now) OR (status = :canceled)",now: Time.zone.now, canceled: Reservation.statuses[:canceled]).order(start_at: :desc)
    end

    def new
      @stylist_id = params[:stylist_id]
      @date = params[:date]
      @time_str = params[:time_str]
      @menu_ids = params[:menu_ids]

      @stylist = User.find(@stylist_id)

      @user = current_user

      @menus = Menu.where(id: @menu_ids).to_a

      @total_duration = @menus.sum(&:duration)
      @total_price  = @menus.sum(&:price)

      date_time_str = "#{@date} #{@time_str}"
      @start_time_obj = begin
        Time.zone.parse(date_time_str)
      rescue StandardError
        nil
      end
    end

    def show
      @stylist = @reservation.stylist
      @menus   = @reservation.menus

      @total_duration = @menus.sum(&:duration)
      @total_price    = @menus.sum(&:price)
    end

    def create
      stylist_id = params[:stylist_id]
      date = params[:date]
      time_str = params[:time_str]
      menu_ids = params[:menu_ids]

      stylist = User.find(stylist_id)
      user = current_user
      menus = Menu.where(id: menu_ids)

      total_duration = menus.sum(&:duration)
      menus.sum(&:price)

      start_time_obj = begin
        Time.zone.parse("#{date} #{time_str}")
      rescue StandardError
        nil
      end
      end_time_obj = (start_time_obj + total_duration.minutes if start_time_obj && total_duration)

      @reservation = Reservation.new(
        customer_id: user.id,
        stylist_id: stylist.id,
        start_at: start_time_obj,
        end_at: end_time_obj
      )

      @reservation.menu_ids = menu_ids
      if @reservation.save

        redirect_to customers_reservation_path(@reservation), notice: I18n.t('flash.reservation_confirmed')
      else
        @stylist = stylist
        @menus = menus
        @date = date
        @time_str = time_str
        @menu_ids = menu_ids
        @total_duration = total_duration
        @total_price = menus.sum(&:price)
        @start_time_obj = start_time_obj
        flash.now[:alert] = '予約の保存に失敗しました。'
        render :new
      end
    end

    def cancel
      @reservation = Reservation.find(params[:id])
      @reservation.canceled!
      redirect_to customers_reservations_path(date: @reservation.start_at.to_date),
                  notice: I18n.t('flash.reservation_cancelled')
    end

    private

    def set_reservation
      @reservation = current_user.reservations.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to customers_reservations_path, alert: "予約が見つかりません。"
    end
  end
end
