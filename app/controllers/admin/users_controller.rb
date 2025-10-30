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
      # subscription_exemptをtrueに変更する場合、Stripeサブスクリプションも解約
      if exempting_subscription?
        handle_subscription_exemption
      # ステータスがinactiveに変更される場合、Stripeサブスクリプションも解約
      elsif deactivating_stylist?
        handle_stylist_deactivation
      elsif @user.update(user_params)
        redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # rubocop:disable Metrics/AbcSize
    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.cannot_deactivate_self')
      elsif @user.admin? && User.where(role: :admin, status: :active).count <= 1
        redirect_to admin_users_path, alert: I18n.t('flash.admin.users.cannot_deactivate_last_admin')
      else
        begin
          @user.deactivate_account!
          redirect_to admin_users_path, notice: I18n.t('flash.admin.users.deactivated')
        rescue Stripe::StripeError => e
          Rails.logger.error "管理者による無効化時のStripe解約失敗 (User ##{@user.id}): #{e.message}"
          redirect_to admin_users_path, alert: I18n.t('flash.admin.users.stripe_cancel_failed')
        rescue StandardError => e
          Rails.logger.error "管理者による無効化失敗 (User ##{@user.id}): #{e.message}"
          redirect_to admin_users_path, alert: I18n.t('flash.admin.users.deactivation_failed')
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

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
      # roleの変更は管理者のみ、かつ自分以外のユーザーに対してのみ許可
      permitted = %i[family_name given_name family_name_kana given_name_kana
                     email gender date_of_birth status
                     subscription_exempt subscription_exempt_reason]

      # 管理者が他のユーザーのroleを変更する場合のみroleを許可
      permitted << :role if current_user.admin? && @user != current_user

      params.require(:user).permit(permitted)
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

    def exempting_subscription?
      # チェックボックスは "1" または "true" を送信
      ['1', 'true', true].include?(user_params[:subscription_exempt]) &&
        !@user.subscription_exempt? &&
        @user.stripe_subscription_id.present?
    end

    def handle_subscription_exemption
      @user.cancel_stripe_subscription_for_exemption
      @user.update(user_params)
      redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.exempted_and_cancelled')
    rescue Stripe::StripeError => e
      Rails.logger.error "免除設定時のStripe解約失敗 (User ##{@user.id}): #{e.message}"
      redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.stripe_cancel_failed')
    rescue StandardError => e
      Rails.logger.error "免除設定失敗 (User ##{@user.id}): #{e.message}"
      redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.exemption_failed')
    end

    def deactivating_stylist?
      user_params[:status] == 'inactive' && @user.status != 'inactive' && @user.stylist?
    end

    def handle_stylist_deactivation
      @user.deactivate_account!
      redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.deactivated')
    rescue Stripe::StripeError => e
      Rails.logger.error "管理者による無効化時のStripe解約失敗 (User ##{@user.id}): #{e.message}"
      redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.stripe_cancel_failed')
    rescue StandardError => e
      Rails.logger.error "管理者による無効化失敗 (User ##{@user.id}): #{e.message}"
      redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.deactivation_failed')
    end
  end
end
