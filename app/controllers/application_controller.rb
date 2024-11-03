# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
    def after_sign_in_path_for(resource)
    case resource.role
    when 'customer'
      customer_dashboard_path
    when 'stylist'
      stylist_dashboard_path
    else
      root_path
    end
  end
end
