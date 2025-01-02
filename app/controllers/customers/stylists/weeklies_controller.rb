# frozen_string_literal: true

module Customers
  module Stylists
    class WeekliesController < ApplicationController
      def index
        set_stylist
        set_selected_menus
        set_dates_and_time_slots
        @time_slots = []
        start_time = Time.zone.parse('10:00')
        end_time = Time.zone.parse('21:00')
        while start_time < end_time
          @time_slots << start_time.strftime('%H:%M')
          start_time += 30.minutes
        end
      end

      private

      def set_stylist
        @stylist = User.find(params[:stylist_id])
      end

      def set_selected_menus
        @selected_menu_ids = params[:menu_ids] || []
        @selected_menus    = @stylist.menus.where(id: @selected_menu_ids)
      end

      def set_dates_and_time_slots
        @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
        @dates = (@start_date..(@start_date + 6.days)).to_a
      end
    end
  end
end
