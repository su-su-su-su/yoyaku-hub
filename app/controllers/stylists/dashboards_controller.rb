# frozen_string_literal: true

module Stylists
  class DashboardsController < Stylists::ApplicationController
    def show
      @stylist = current_user
      @today = Time.zone.today
    end
  end
end
