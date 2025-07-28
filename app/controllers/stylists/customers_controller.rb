# frozen_string_literal: true

module Stylists
  class CustomersController < Stylists::ApplicationController
    def index
      @customers = User.customers_for_stylist(current_user.id)
      @customers = @customers.search_by_name(params[:query]) if params[:query].present?
      @customers = @customers.order(:family_name_kana, :given_name_kana)
    end

    def show
      @customer = User.customers_for_stylist(current_user.id).find(params[:id])
    end
  end
end
