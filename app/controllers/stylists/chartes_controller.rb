# frozen_string_literal: true

module Stylists
  class ChartesController < Stylists::ApplicationController
    before_action :set_customer, only: %i[index show edit update destroy]
    before_action :set_charte, only: %i[show edit update destroy]
    before_action :set_reservation, only: %i[new create]

    def index
      @chartes = current_user.stylist_chartes
        .where(customer: @customer)
        .includes(:reservation)
        .recent

      @paid_reservations = current_user.stylist_reservations
        .where(customer: @customer, status: :paid)
        .includes(:menus, :accounting)
        .order(start_at: :desc)
    end

    def show; end

    def new
      @charte = current_user.stylist_chartes.build(
        customer: @reservation.customer,
        reservation: @reservation
      )
    end

    def edit; end

    def create
      @charte = current_user.stylist_chartes.build(charte_params)
      @charte.customer = @reservation.customer
      @charte.reservation = @reservation

      if @charte.save
        redirect_with_toast stylists_customer_charte_path(@charte.customer, @charte), t('stylists.chartes.created'),
          type: :success
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @charte.update(charte_params)
        redirect_with_toast stylists_customer_charte_path(@customer, @charte), t('stylists.chartes.updated'),
          type: :success
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @charte.destroy!
      redirect_with_toast stylists_customer_chartes_path(@customer), t('stylists.chartes.deleted'), type: :success
    end

    private

    def set_customer
      @customer = User.customers_for_stylist(current_user.id).find(params[:customer_id])
    rescue ActiveRecord::RecordNotFound
      redirect_with_toast stylists_dashboard_path, t('stylists.chartes.access_denied'), type: :error
    end

    def set_charte
      @charte = current_user.stylist_chartes.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_with_toast stylists_dashboard_path, t('stylists.chartes.access_denied'), type: :error
    end

    def set_reservation
      @reservation = current_user.stylist_reservations.find(params[:id])
    end

    def charte_params
      params.require(:charte).permit(:treatment_memo, :remarks)
    end
  end
end
