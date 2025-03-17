# frozen_string_literal: true

module Stylists
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      @user.validating_profile = true
      if @user.update(stylist_params)
        redirect_to stylists_dashboard_path, notice: t('stylists.profiles.updated')
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
