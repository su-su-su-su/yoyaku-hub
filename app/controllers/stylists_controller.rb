# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist_role

  def show
    @stylist_id = current_user.id
    @show_shift_settings_warning = !current_user.default_shift_settings_configured?
    @show_menu_warning = !current_user.registered_menus?
    @show_current_month_setup_prompt = !current_user.current_month_shifts_configured?
    @show_next_month_setup_prompt = false
    is_next_month_unconfigured = !current_user.next_month_shifts_configured?
    is_after_20th = Date.current.day > 20
    @show_next_month_setup_prompt = true if is_next_month_unconfigured && is_after_20th
    @menu_url = "https://yoyakuhub.jp/customers/stylists/#{@stylist_id}/menus"
    set_date_info_for_dashboard
  end

  private

  def set_date_info_for_dashboard
    today = Time.zone.today
    @this_month_year = today.year
    @this_month = today.month
    next_month_date = today.next_month
    @next_month_year = next_month_date.year
    @next_month = next_month_date.month
    next_next_month_date = next_month_date.next_month
    @next_next_month_year = next_next_month_date.year
    @next_next_month = next_next_month_date.month
  end
end
