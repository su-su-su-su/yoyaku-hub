# frozen_string_literal: true

module Customers
  class ProfilesController < Customers::ApplicationController
    before_action :ensure_customer_role

    def edit
      @user = current_user
    end

    def update
      if demo_mode? && current_user.email&.include?('@example.com')
        redirect_to customers_dashboard_path, alert: t('demo.profile_edit_disabled')
        return
      end

      @user = current_user
      @user.assign_attributes(customer_params)
      if @user.save(context: :profile_completion)
        redirect_to customers_dashboard_path, notice: t('customers.profiles.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

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
