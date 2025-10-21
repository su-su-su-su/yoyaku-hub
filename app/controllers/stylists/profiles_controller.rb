# frozen_string_literal: true

module Stylists
  class ProfilesController < Stylists::ApplicationController
    def edit
      @user = current_user
    end

    def update
      if demo_mode? && current_user.email&.include?('@example.com')
        redirect_with_toast stylists_dashboard_path, t('demo.profile_edit_disabled'), type: :error
        return
      end

      @user = current_user
      @user.assign_attributes(stylist_params)
      if @user.save(context: :profile_completion)
        # プロフィール保存後は常にダッシュボードへ
        # （サブスク登録は新規登録時に済んでいるはず）
        redirect_with_toast stylists_dashboard_path, t('stylists.profiles.updated'), type: :success
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def stylist_params
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
