# frozen_string_literal: true

module Customers
  class ReservationsController < ApplicationController
    def show
      @stylist_id = params[:stylist_id]
      @date       = params[:date]
      @time_str   = params[:time_str]
      @menu_ids   = params[:menu_ids]

      @stylist = User.find(@stylist_id)

      @user = current_user

      @menus = Menu.where(id: @menu_ids).to_a

      @total_duration = @menus.sum(&:duration)
      @total_price    = @menus.sum(&:price)

      date_time_str = "#{@date} #{@time_str}"
      @start_time_obj = begin
        Time.zone.parse(date_time_str)
      rescue StandardError
        nil
      end
    end

    def create; end
  end
end
