# frozen_string_literal: true

module Customers
  class ReservationsController < ApplicationController
    before_action :set_reservation, only: [:show, :destroy]

    def index
      user = current_user
      @upcoming_reservations = user.reservations.where("start_at >= ?", Time.zone.now).order(:start_at)
      @past_reservations = user.reservations.where("start_at < ?", Time.zone.now).order(start_at: :desc)
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

      if @reservation.save
        @reservation.menus << menus

        start_slot = (start_time_obj.hour * 2) + (start_time_obj.min >= 30 ? 1 : 0)
        end_slot = (end_time_obj.hour * 2) + (end_time_obj.min >= 30 ? 1 : 0)

        (start_slot...end_slot).each do |slot|
          limit = ReservationLimit.find_by(stylist_id: stylist.id, target_date: date, time_slot: slot)
          if limit&.max_reservations&.positive?
            limit.max_reservations -= 1
            limit.save!
          end
        end

        redirect_to customers_dashboard_path, notice: '予約を確定しました。'
      else
        flash.now[:alert] = '予約の保存に失敗しました。'
        render :show
      end
    end

    def destroy
      if @reservation.destroy
        redirect_to customers_reservations_path, notice: "予約がキャンセルされました。"
      else
        redirect_to customer_reservation_path(@reservation), alert: "予約のキャンセルに失敗しました。"
      end
    end

    private

    def set_reservation
      @reservation = current_user.reservations.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to customers_reservations_path, alert: "予約が見つかりません。"
    end
  end
end
