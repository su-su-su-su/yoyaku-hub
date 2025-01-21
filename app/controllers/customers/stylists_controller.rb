# frozen_string_literal: true

module Customers
  class StylistsController < ApplicationController
    def index
      @stylists = User.where(role: :stylist)
                      .joins(:stylist_reservations).where(stylist_reservations: { customer_id: current_user.id })
                      .where(stylist_reservations: { created_at: 3.years.ago.. }).distinct
    end
  end
end
