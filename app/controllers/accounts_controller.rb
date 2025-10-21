# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist, only: [:new]

  # GET /account/deactivate
  def new
    # 退会確認ページを表示
    return unless current_user.demo_user?

    redirect_to root_path, alert: t('accounts.demo_user_cannot_deactivate')
  end

  # DELETE /account/deactivate
  # rubocop:disable Metrics/AbcSize
  def destroy
    if current_user.demo_user?
      redirect_to root_path, alert: t('accounts.demo_user_cannot_deactivate')
      return
    end

    begin
      current_user.deactivate_account!
      sign_out current_user

      flash[:notice] = t('accounts.deactivation_completed')
      redirect_to root_path, status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "退会処理失敗 (User ##{current_user.id}): #{e.message}"
      redirect_back fallback_location: root_path, alert: t('accounts.deactivation_failed')
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe解約失敗 (User ##{current_user.id}): #{e.message}"
      redirect_back fallback_location: root_path, alert: t('accounts.stripe_cancel_failed')
    rescue StandardError => e
      Rails.logger.error "退会処理エラー (User ##{current_user.id}): #{e.class} - #{e.message}"
      redirect_back fallback_location: root_path, alert: t('accounts.deactivation_error')
    end
  end
  # rubocop:enable Metrics/AbcSize

  private

  def ensure_stylist
    return if current_user.stylist?

    redirect_to root_path, alert: t('accounts.access_denied')
  end
end
