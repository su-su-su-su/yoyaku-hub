# frozen_string_literal: true

module Admin
  # rubocop:disable Metrics/ClassLength
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
      # subscription_exemptの変更を検知してStripeと同期
      if subscription_exempt_changed?
        handle_subscription_exempt_change
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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def toggle_subscription_exemption
      @user = User.with_inactive.find(params[:id])

      if @user.stripe_subscription_id.blank?
        redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.no_subscription')
        return
      end

      begin
        if @user.subscription_exempt?
          # 免除解除: 割引を削除
          # discounts配列を空にすることで全ての割引を削除
          Stripe::Subscription.update(
            @user.stripe_subscription_id,
            { discounts: [] }
          )

          @user.update!(subscription_exempt: false, subscription_exempt_reason: nil)
          redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.exemption_removed')
        else
          # 免除適用: クーポンを適用（新しいAPI形式）
          coupon_id = ENV['STRIPE_EXEMPTION_COUPON_ID'] || ENV.fetch('STRIPE_MONITOR_COUPON_ID', nil)

          unless coupon_id
            Rails.logger.error '免除用クーポンIDが環境変数に設定されていません'
            redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.exemption_coupon_missing')
            return
          end
          Stripe::Subscription.update(
            @user.stripe_subscription_id,
            {
              discounts: [
                { coupon: coupon_id }
              ]
            }
          )
          @user.update!(
            subscription_exempt: true,
            subscription_exempt_reason: 'モニター免除（100%割引クーポン適用）'
          )
          redirect_to admin_user_path(@user), notice: I18n.t('flash.admin.users.exemption_applied')
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "免除トグル時のエラー (User ##{@user.id}): #{e.message}"
        redirect_to admin_user_path(@user), alert: "Stripeエラー: #{e.message}"
      rescue StandardError => e
        Rails.logger.error "免除トグル失敗 (User ##{@user.id}): #{e.message}"
        redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.exemption_toggle_error')
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

    def subscription_exempt_changed?
      # Stripeサブスクリプションがあり、subscription_exemptが変更される場合
      return false if @user.stripe_subscription_id.blank?

      # チェックボックスの値を正規化（"0" = false, "1" = true）
      new_value = ['1', 'true', true].include?(user_params[:subscription_exempt])
      new_value != @user.subscription_exempt?
    end

    def handle_subscription_exempt_change
      new_exempt = ['1', 'true', true].include?(user_params[:subscription_exempt])

      begin
        update_stripe_subscription_exemption(new_exempt)
        update_user_and_redirect(new_exempt)
      rescue Stripe::StripeError => e
        Rails.logger.error "免除設定変更時のエラー (User ##{@user.id}): #{e.message}"
        redirect_to edit_admin_user_path(@user), alert: "Stripeエラー: #{e.message}"
      end
    end

    def update_stripe_subscription_exemption(exempt)
      if exempt
        coupon_id = ENV['STRIPE_EXEMPTION_COUPON_ID'] || ENV.fetch('STRIPE_MONITOR_COUPON_ID', nil)
        return handle_missing_coupon unless coupon_id

        Stripe::Subscription.update(@user.stripe_subscription_id, { discounts: [{ coupon: coupon_id }] })
      else
        Stripe::Subscription.update(@user.stripe_subscription_id, { discounts: [] })
      end
    end

    def handle_missing_coupon
      Rails.logger.error '免除用クーポンIDが環境変数に設定されていません'
      redirect_to admin_user_path(@user), alert: I18n.t('flash.admin.users.exemption_coupon_missing')
    end

    def update_user_and_redirect(exempt)
      if @user.update(user_params)
        message_key = exempt ? 'flash.admin.users.exemption_applied' : 'flash.admin.users.exemption_removed'
        redirect_to admin_user_path(@user), notice: I18n.t(message_key)
      else
        render :edit, status: :unprocessable_entity
      end
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
  # rubocop:enable Metrics/ClassLength
end
