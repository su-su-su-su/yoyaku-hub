# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :check_demo_mode
  before_action :check_subscription_status

  protected

  def after_sign_in_path_for(resource)
    case resource.role
    when 'stylist'
      stylists_dashboard_path
    when 'customer'
      # 保存されたURLがあればそちらへリダイレクト（スタイリストメニューページなど）
      stored_location_for(:user) || customers_dashboard_path
    else
      root_path
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
  end

  private

  def ensure_role(role)
    allowed_roles = %w[customer stylist]
    return unless allowed_roles.include?(role)
    return if current_user&.role == role

    redirect_with_toast root_path, t('alerts.no_permission'), type: :error
  end

  def ensure_stylist_role
    ensure_role('stylist')
  end

  def ensure_customer_role
    ensure_role('customer')
  end

  def after_sign_out_path_for(_resource_or_scope)
    session.delete(:demo_mode)
    new_user_session_path
  end

  def check_demo_mode
    return if params[:demo].blank?
    return unless demo_mode_enabled?

    # デモモードの場合、既にログイン中でも強制的にログアウトしてからデモユーザーでログイン
    if user_signed_in?
      sign_out(current_user)
      session.delete(:demo_mode)
    end

    demo_user = find_demo_user(params[:demo])
    return unless demo_user

    sign_in(demo_user)
    session[:demo_mode] = true
  end

  def demo_mode_enabled?
    if Rails.env.test?
      ENV['ENABLE_DEMO_MODE'] == 'true'
    else
      true
    end
  end

  def find_demo_user(demo_type)
    session_id = request.session.id.to_s
    session_id = SecureRandom.hex(8) if session_id.blank?

    case demo_type
    when 'stylist'
      User.find_or_create_demo_stylist(session_id)
    when 'customer'
      User.find_or_create_demo_customer(session_id)
    end
  end

  def demo_mode?
    session[:demo_mode] == true
  end

  def redirect_with_toast(path, message, type: :info)
    flash[:toast] = { message: message, type: type }
    redirect_to path, status: :see_other
  end

  def redirect_back_with_toast(fallback_location:, message:, type: :info)
    flash[:toast] = { message: message, type: type }
    redirect_back fallback_location: fallback_location
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def check_subscription_status
    return unless user_signed_in?

    # ユーザーステータスが無効化されている場合、強制ログアウト
    # （支払い失敗やサブスクリプション削除により無効化）
    if current_user.inactive?
      sign_out current_user
      redirect_to new_user_session_path, alert: t('application.account_inactive')
      return
    end

    return if current_user.customer? # カスタマーは課金対象外
    return if current_user.admin? # 管理者は課金対象外
    return if current_user.demo_user? # デモユーザーは課金対象外
    return if current_user.subscription_exempt? # モニター等は課金対象外
    return if controller_name == 'subscriptions' # サブスクリプション画面は常にアクセス可
    return if controller_name == 'sessions' # セッション（ログイン・ログアウト）は常にアクセス可
    return if controller_name == 'profiles' # プロフィール編集は常にアクセス可（新規登録直後）
    return if devise_controller? # Devise関連は常にアクセス可

    # Stripe APIキーが設定されていない場合
    if Rails.configuration.stripe[:secret_key].blank?
      # スタイリストでまだStripe Checkoutを完了していない場合のみ登録画面へ誘導
      if current_user.stylist? && !current_user.stripe_setup_complete?
        redirect_to new_subscription_path, alert: t('subscriptions.registration_required')
        return
      end
      # それ以外はスキップ（開発環境用）
      return
    end

    # スタイリストで、まだStripe Checkoutを完了していない場合は登録ページへ
    if current_user.stylist? && !current_user.stripe_setup_complete?
      redirect_to new_subscription_path, alert: t('subscriptions.registration_required')
      return
    end

    # トライアル期間中またはサブスクリプション有効な場合は通過
    return if current_user.subscription_active?

    # サブスクリプションが必要な場合は登録ページへリダイレクト
    return unless current_user.needs_subscription?

    redirect_to new_subscription_path, alert: t('subscriptions.registration_required')
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
# rubocop:enable Metrics/ClassLength
