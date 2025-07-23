# frozen_string_literal: true

module Stylists
  class AccountingsController < Stylists::ApplicationController
    before_action :set_reservation, only: %i[new create]
    before_action :set_accounting, only: %i[show edit update]

    def show; end

    def new
      if @reservation.accounting&.completed?
        redirect_to edit_stylists_accounting_path(@reservation.accounting),
                    notice: '会計は既に完了しています。修正画面に移動します。'
        return
      end

      @reservation.accounting.destroy if @reservation.accounting&.pending?

      @accounting = @reservation.build_accounting(
        total_amount: @reservation.menus.sum(&:price)
      )
      @accounting.accounting_payments.build
    end

    def edit
      @accounting.accounting_payments.build if @accounting.accounting_payments.empty?
    end

    def create
      total_amount = params[:accounting][:total_amount]
      payment_attributes = payment_params[:accounting_payments_attributes]

      @accounting = Accounting.create_with_payments(
        @reservation,
        total_amount,
        payment_attributes
      )

      if @accounting.persisted?
        redirect_to stylists_reservation_path(@reservation),
                    notice: '会計が完了しました'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      total_amount = accounting_params[:total_amount]
      payment_attributes = payment_params[:accounting_payments_attributes]

      if @accounting.update_with_payments(total_amount, payment_attributes)
        redirect_to stylists_reservation_path(@accounting.reservation),
                    notice: '会計が修正されました'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_reservation
      @reservation = current_user.stylist_reservations.find(params[:reservation_id])
    end

    def set_accounting
      @accounting = Accounting.find(params[:id])
      @reservation = @accounting.reservation
    end

    def accounting_params
      params.require(:accounting).permit(
        :total_amount,
        accounting_payments_attributes: %i[payment_method amount _destroy]
      )
    end

    def payment_params
      params.require(:accounting).permit(
        accounting_payments_attributes: %i[payment_method amount _destroy]
      )
    end
  end
end
