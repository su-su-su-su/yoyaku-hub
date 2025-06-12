# frozen_string_literal: true

module Customers
  class StylistsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_customer_role
    before_action :ensure_profile_complete

    def index
      @stylists = User.where(role: :stylist)
        .joins(:stylist_reservations)
        .where(stylist_reservations: { customer_id: current_user.id })
        .where(stylist_reservations: { created_at: 3.years.ago.. })
        .distinct
    end

    def ensure_profile_complete
      return if current_user.profile_complete?

      redirect_to edit_customers_profile_path,
        alert: t('customers.profiles.incomplete_profile')
    end
  end
end
