# frozen_string_literal: true

module Stylists
  class AccountingsController < Stylists::ApplicationController
    before_action :set_reservation, only: %i[new create]
    before_action :set_accounting, only: %i[show edit update]

    def show; end

    def new
      if @reservation.accounting&.completed?
        redirect_to edit_stylists_accounting_path(@reservation.accounting),
          notice: t('stylists.accountings.already_completed')
        return
      end

      @reservation.accounting.destroy if @reservation.accounting&.pending?

      @accounting = @reservation.build_accounting(
        total_amount: @reservation.menus.sum(&:price)
      )
      @accounting.accounting_payments.build
      # 店販商品の初期フィールドは作成しない
      @products = current_user.products.active.order(:name)
    end

    def edit
      @accounting.accounting_payments.build if @accounting.accounting_payments.empty?
      # 編集画面でも初期の商品フィールドは作成しない（新規追加時のみ）
      @products = current_user.products.active.order(:name)
    end

    def create
      # 支払い情報は別途処理するので、ここでは含めない
      build_params = { total_amount: accounting_params[:total_amount] }

      # 商品情報がある場合のみ追加
      if accounting_params[:accounting_products_attributes].present?
        build_params[:accounting_products_attributes] = accounting_params[:accounting_products_attributes]
      end

      @accounting = @reservation.build_accounting(build_params)

      if @accounting.save_with_payments_and_products(payment_params[:accounting_payments_attributes])
        redirect_to stylists_reservation_path(@reservation),
          notice: t('stylists.accountings.completed')
      else
        @products = current_user.products.active.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @accounting.update_with_payments_and_products(accounting_params,
        payment_params[:accounting_payments_attributes])
        redirect_to stylists_reservation_path(@accounting.reservation),
          notice: t('stylists.accountings.updated')
      else
        @products = current_user.products.active.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_reservation
      @reservation = current_user.stylist_reservations.find(params[:id])
    end

    def set_accounting
      @accounting = Accounting.find(params[:id])
      @reservation = @accounting.reservation
    end

    def accounting_params
      params.require(:accounting).permit(
        :total_amount,
        accounting_payments_attributes: %i[id payment_method amount _destroy],
        accounting_products_attributes: %i[id product_id quantity actual_price _destroy]
      )
    end

    def payment_params
      params.require(:accounting).permit(
        accounting_payments_attributes: %i[payment_method amount _destroy]
      )
    end
  end
end
