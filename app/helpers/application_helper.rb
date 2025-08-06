# frozen_string_literal: true

module ApplicationHelper
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

  def demo_mode?
    session[:demo_mode] == true
  end
end
