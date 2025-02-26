# frozen_string_literal: true

module Customers
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:customer) }

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if @user.update(customer_params)
        redirect_to customers_dashboard_path, otice: t('customers.profiles.updated')
      else
        render :edit
      end
    end

    private

    def ensure_customer
      redirect_to root_path unless current_user&.role == 'customer'
    end

    def customer_params
      params.require(:user).permit(
        :family_name,
        :given_name,
        :family_name_kana,
        :given_name_kana,
        :gender,
        :date_of_birth
      )
    end
  end
end
