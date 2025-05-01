# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist_role

  def show
    @show_shift_settings_warning = !current_user.default_shift_settings_configured?
    @show_menu_warning = !current_user.has_registered_menus?
    @stylist_id = current_user.id
  end

  private

  def ensure_stylist_role
    ensure_role('stylist')
  end
end
