# frozen_string_literal: true

module Customers
  class StylistsController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:customer) }
    before_action :ensure_profile_complete


    def index
      @stylists = User.where(role: :stylist)
                      .joins(:stylist_reservations).where(stylist_reservations: { customer_id: current_user.id })
                      .where(stylist_reservations: { created_at: 3.years.ago.. }).distinct
    end

    def ensure_profile_complete
      unless current_user.profile_complete?
        redirect_to edit_customers_profile_path,
        alert: I18n.t('customers.profiles.incomplete_profile')
      end
    end
  end
end
