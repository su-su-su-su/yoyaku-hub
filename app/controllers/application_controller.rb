# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

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
    return if current_user&.public_send("#{role}?")

    redirect_to root_path, alert: t('alerts.no_permission')
  end
end
