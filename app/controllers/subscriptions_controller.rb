# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class SubscriptionsController < ApplicationController
  # トライアル期間（6ヶ月）
  TRIAL_PERIOD = 6.months

  # 月額料金（表示用）
  MONTHLY_PRICE = 3850

  # 年額料金（表示用）
  YEARLY_PRICE = MONTHLY_PRICE * 12

  before_action :authenticate_user!
  before_action :ensure_stylist_or_admin
  before_action :ensure_stripe_customer

  def new
    # Stripe Checkoutを完了済み（実際の決済完了）の場合はリダイレクト
    return if current_user.stripe_subscription_id.blank?

    redirect_to stylists_dashboard_path, notice: t('subscriptions.already_exists')
    nil

    # エラーがない場合は、サブスクリプション登録画面を表示
    # （@stripe_errorがtrueの場合はエラー画面が表示される）
  end

  # rubocop:disable Metrics/AbcSize
  def create
    session = Stripe::Checkout::Session.create(
      customer: current_user.stripe_customer_id,
      mode: 'subscription',
      line_items: [{
        price: Rails.configuration.stripe[:price_id],
        quantity: 1
      }],
      subscription_data: {
        trial_end: current_user.trial_ends_at&.to_i || TRIAL_PERIOD.from_now.to_i
      },
      success_url: "#{success_subscription_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: cancel_subscription_url
    )

    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe Checkout Session作成エラー: #{e.message}"
    redirect_to new_subscription_path, alert: t('subscriptions.checkout_creation_failed')
  end
  # rubocop:enable Metrics/AbcSize

  def success
    # Stripe Checkout Sessionから即座にsubscription_idを取得して保存
    # Webhookの到着を待たずに、ユーザー体験を向上させる
    save_subscription_from_checkout_session

    flash[:notice] = t('subscriptions.registration_completed')

    # プロフィールが未完成の場合（新規登録直後）はプロフィール編集へ
    redirect_to_profile_or_dashboard
  end

  def cancel
    flash[:alert] = t('subscriptions.registration_cancelled')
    redirect_to new_subscription_path
  end

  private

  def ensure_stylist_or_admin
    return if current_user.stylist?

    redirect_to root_path, alert: t('subscriptions.access_denied')
  end

  def save_subscription_from_checkout_session
    session_id = extract_session_id
    return unless valid_session_id?(session_id)

    retrieve_and_save_subscription(session_id)
  rescue Stripe::StripeError => e
    Rails.logger.error "Checkout Session取得エラー (User ##{current_user.id}): #{e.message}"
    # エラーが発生してもWebhookで後から更新されるため、処理は続行
  end

  def extract_session_id
    session_id = params[:session_id]
    session_id = session_id.first while session_id.is_a?(Array)
    Rails.logger.info "Session ID type: #{session_id.class}, value: #{session_id.inspect}"
    session_id
  end

  def valid_session_id?(session_id)
    session_id.present? && session_id.is_a?(String) && session_id != '{CHECKOUT_SESSION_ID}'
  end

  def retrieve_and_save_subscription(session_id)
    session = Stripe::Checkout::Session.retrieve(
      { id: session_id, expand: ['subscription'] }
    )

    return if session.subscription.blank?

    save_subscription_data(session.subscription)
  end

  def save_subscription_data(subscription)
    trial_end = subscription.trial_end ? Time.zone.at(subscription.trial_end) : nil

    # rubocop:disable Rails/SkipsModelValidations
    current_user.update_columns(
      stripe_subscription_id: subscription.id,
      subscription_status: subscription.status,
      trial_ends_at: trial_end,
      updated_at: Time.current
    )
    # rubocop:enable Rails/SkipsModelValidations

    Rails.logger.info "Checkout成功時にサブスクリプション情報を即座に保存 (User ##{current_user.id}): #{subscription.id}"
  end

  def redirect_to_profile_or_dashboard
    if current_user.profile_complete?
      redirect_to stylists_dashboard_path
    else
      redirect_to edit_stylists_profile_path
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def ensure_stripe_customer
    return if current_user.stripe_customer_id.present?

    # Stripe APIキーが設定されていない場合はスキップ（開発環境用）
    if Rails.configuration.stripe[:secret_key].blank?
      Rails.logger.warn "Stripe APIキーが設定されていません (User ##{current_user.id})"
      flash.now[:alert] = t('subscriptions.stripe_not_configured')
      return
    end

    # Stripe Customerが作成されていない場合、作成を試みる
    begin
      customer = Stripe::Customer.create(
        email: current_user.email,
        metadata: {
          user_id: current_user.id,
          role: current_user.role
        }
      )

      # Stripe APIの結果を確実に保存するため、意図的にupdate_columnsを使用
      # バリデーション・コールバックは不要（システム内部処理のため）
      # rubocop:disable Rails/SkipsModelValidations
      current_user.update_columns(
        stripe_customer_id: customer.id,
        trial_ends_at: TRIAL_PERIOD.from_now
      )
      # rubocop:enable Rails/SkipsModelValidations

      Rails.logger.info "Stripe Customer作成成功 (User ##{current_user.id}): #{customer.id}"
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe Customer作成失敗 (User ##{current_user.id}): #{e.message}"
      flash.now[:alert] = t('subscriptions.invalid_email')
      @stripe_error = true
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
