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

    def new
      @customer = User.new(role: :customer)
    end

    def edit
      @customer = find_editable_customer
    end

    def create
      @customer = User.new(customer_params)
      @customer.role = :customer
      @customer.created_by_stylist_id = current_user.id
      @customer.password = generate_random_password
      @customer.email = generate_dummy_email if @customer.email.blank?

      if @customer.save
        redirect_to stylists_customers_path, notice: t('flash.customers.stylists.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @customer = find_editable_customer
      return unless @customer

      @customer.assign_attributes(customer_params)
      @customer.email = generate_dummy_email if @customer.email.blank?

      if @customer.save
        redirect_to stylists_customer_path(@customer), notice: t('flash.customers.stylists.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def customer_params
      params.require(:user).permit(:family_name, :given_name, :family_name_kana, :given_name_kana, :gender,
        :date_of_birth, :email)
    end

    def generate_random_password
      SecureRandom.alphanumeric(12)
    end

    def generate_dummy_email
      timestamp = Time.current.strftime('%Y%m%d%H%M%S')
      random_string = SecureRandom.alphanumeric(8)
      "dummy_#{timestamp}_#{random_string}@no-email-dummy.invalid"
    end

    def find_editable_customer
      customer = User.customers_for_stylist(current_user.id).find(params[:id])

      unless customer.created_by_stylist_id == current_user.id
        redirect_to stylists_customers_path, alert: t('flash.customers.stylists.edit_permission_denied')
        return
      end

      customer
    end
  end
end
