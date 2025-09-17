# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :set_user, only: %i[show edit update destroy]

    def index
      @users = build_user_scope
    end

    def show
      @reservations = if @user.stylist?
                        @user.stylist_reservations.includes(:customer, :menus).order(start_at: :desc).limit(10)
                      else
                        @user.reservations.includes(:stylist, :menus).order(start_at: :desc).limit(10)
                      end
    end

    def edit; end

    def update
      # 管理者以外がroleを変更できないようにする
      filtered_params = user_params
      filtered_params = user_params.except(:role) if params[:user][:role].present? && @user == current_user

      if @user.update(filtered_params)
        redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.cannot_deactivate_self')
      elsif @user.admin? && User.where(role: :admin, status: :active).count <= 1
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.cannot_deactivate_last_admin')
      elsif @user.update(status: :inactive)
        redirect_to admin_users_path, notice: I18n.t('flash.admin.users.deactivated')
      else
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.deactivation_failed')
      end
    end

    def activate
      @user = User.with_inactive.find(params[:id])
      if @user.update(status: :active)
        redirect_to admin_users_path, notice: I18n.t('flash.admin.users.activated')
      else
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.activation_failed')
      end
    end

    private

    def set_user
      @user = User.with_inactive.find(params[:id])
    end

    def user_params
      params.require(:user).permit(
        :family_name, :given_name, :family_name_kana, :given_name_kana,
        :email, :role, :gender, :date_of_birth
      )
    end

    def build_user_scope
      scope = User.with_inactive.order(:status, :role, :created_at)
      apply_filters(scope)
    end

    def apply_filters(scope)
      scope = scope.search_by_name(params[:query]) if params[:query].present?
      scope = scope.where(role: params[:role]) if params[:role].present?
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope
    end
  end
end
