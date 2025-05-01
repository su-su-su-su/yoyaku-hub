# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist Dashboard Setup Warnings' do
  let(:stylist) { create(:user, :stylist) }

  def create_default_shifts(user)
    create(:working_hour, stylist: user, target_date: nil, day_of_week: nil)
    create(:reservation_limit, stylist: user, target_date: nil, time_slot: nil)
  end

  def create_menu(user)
    create(:menu, stylist: user)
  end

  DEFAULT_SHIFT_WARNING_TEXT = 'シフトの設定してください。'
  MENU_REGISTRATION_WARNING_TEXT = 'メニューを1つ以上登録してください。'

  let(:stylist_dashboard_path) { stylists_dashboard_path }

  before do
    sign_in stylist
  end

  context 'when default shifts are not configured and no menus are registered' do
    before do
      visit stylist_dashboard_path
    end

    it 'shows both default shift setup and menu registration warnings' do
      expect(page).to have_text(DEFAULT_SHIFT_WARNING_TEXT)
      expect(page).to have_text(MENU_REGISTRATION_WARNING_TEXT)
    end
  end

  context 'when only default shifts are not configured (menus are registered)' do
    before do
      create_menu(stylist)
      visit stylist_dashboard_path
    end

    it 'shows only the default shift setup warning' do
      expect(page).to have_text(DEFAULT_SHIFT_WARNING_TEXT)
      expect(page).not_to have_text(MENU_REGISTRATION_WARNING_TEXT)
    end
  end

  context 'when only menus are not registered (default shifts are configured)' do
    before do
      create_default_shifts(stylist)
      visit stylist_dashboard_path
    end

    it 'shows only the menu registration warning' do
      expect(page).not_to have_text(DEFAULT_SHIFT_WARNING_TEXT)
      expect(page).to have_text(MENU_REGISTRATION_WARNING_TEXT)
    end
  end

  context 'when both default shifts and menus are configured' do
    before do
      create_default_shifts(stylist)
      create_menu(stylist)
      visit stylist_dashboard_path
    end

    it 'does not show default shift setup or menu registration warnings' do
      expect(page).not_to have_text(DEFAULT_SHIFT_WARNING_TEXT)
      expect(page).not_to have_text(MENU_REGISTRATION_WARNING_TEXT)
    end
  end
end
