# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :check_demo_mode

  protected

  def after_sign_in_path_for(resource)
    case resource.role
    when 'stylist'
      stylists_dashboard_path
    when 'customer'
      customers_dashboard_path
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

    redirect_to root_path, alert: t('alerts.no_permission')
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
    Rails.env.development? || ENV['ENABLE_DEMO_MODE'] == 'true'
  end

  def find_demo_user(demo_type)
    # セッションIDを取得、存在しない場合はランダムに生成
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
end
