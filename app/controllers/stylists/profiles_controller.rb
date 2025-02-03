# frozen_string_literal: true

module Stylists
  class ProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_stylist

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if @user.update(stylist_params)
        redirect_to stylists_dashboard_path, otice: t('stylists.profiles.updated')
      else
        render :edit
      end
    end

    private

    def ensure_stylist
      redirect_to root_path unless current_user&.role == 'stylist'
    end

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
