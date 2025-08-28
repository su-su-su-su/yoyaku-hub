# frozen_string_literal: true

module Stylists
  class CustomerReservationsController < Stylists::ApplicationController
    def new
      setup_new_form
      search_customers if params[:customer_search].present?

      return unless turbo_frame_request?

      render partial: 'customer_list', locals: { customers: @customers }
    end

    def create
      setup_create_params

      return handle_missing_customer if params[:customer_id].blank?

      build_reservation

      if @reservation.save
        redirect_with_toast stylists_schedules_path(date: @date), t('stylists.reservations.created'), type: :success
      else
        handle_validation_error
      end
    end

    private

    def setup_new_form
      @date = params[:date]
      @time_str = params[:time_str]
      @customers = User.none
      @active_menus = current_user.menus.where(is_active: true)
      @reservation = Reservation.new
    end

    def search_customers
      customers_scope = User.customers_for_stylist(current_user.id)
      customers_scope = customers_scope.search_by_name(params[:customer_search])
      @customers = customers_scope.order(:family_name_kana, :given_name_kana)
    end

    def setup_create_params
      @date = params[:date]
      @time_str = params[:time_str]
      @menu_ids = params[:menu_ids] || []
    end

    def handle_missing_customer
      @reservation = Reservation.new
      @reservation.errors.add(:base, t('stylists.reservations.customer_required'))
      @customers = User.none
      @active_menus = current_user.menus.where(is_active: true)
      render :new, status: :unprocessable_entity
    end

    def build_reservation
      @customer = User.customers_for_stylist(current_user.id).find(params[:customer_id])
      @reservation = Reservation.new(
        customer: @customer,
        stylist: current_user,
        start_date_str: @date,
        start_time_str: @time_str,
        menu_ids: @menu_ids
      )
    end

    def handle_validation_error
      @customers = User.none
      @active_menus = current_user.menus.where(is_active: true)
      render :new, status: :unprocessable_entity
    end
  end
end
