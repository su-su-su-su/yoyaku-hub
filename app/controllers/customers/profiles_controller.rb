# frozen_string_literal: true

module Customers
  class ProfilesController < Customers::ApplicationController
    before_action :ensure_customer_role

    def edit
      @user = current_user
    end

    def update
      if demo_mode? && current_user.email&.include?('@example.com')
        redirect_with_toast customers_dashboard_path, t('demo.profile_edit_disabled'), type: :error
        return
      end

      @user = current_user
      @user.assign_attributes(customer_params)
      if @user.save(context: :profile_completion)
        # 保存されたURL（スタイリストメニューページなど）があればそちらへリダイレクト
        redirect_path = stored_location_for(:user) || customers_dashboard_path
        redirect_with_toast redirect_path, t('customers.profiles.updated'), type: :success
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
