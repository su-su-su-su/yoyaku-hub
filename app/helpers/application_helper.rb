# frozen_string_literal: true

module ApplicationHelper
  def render_navbar
    if user_signed_in?
      if current_user.stylist?
        render 'layouts/navbars/stylist_navbar'
      else
        render 'layouts/navbars/customer_navbar'
      end
    else
      render 'layouts/navbars/guest_navbar'
    end
  end

  def menu_form_url(menu)
    if menu.new_record?
      menus_settings_path
    else
      menus_setting_path(menu_id: menu.id)
    end
  end

  def menu_form_method(menu)
    menu.new_record? ? :post : :patch
  end
end
