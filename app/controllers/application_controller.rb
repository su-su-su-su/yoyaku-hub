# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
  before_action :configure_permitted_parameters, if: :devise_controller?
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

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

  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end
end
