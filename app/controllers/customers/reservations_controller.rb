# frozen_string_literal: true

module Customers
  class ReservationsController < ApplicationController
    def show
      @date       = params[:date]
      @time_str   = params[:time_str]

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
