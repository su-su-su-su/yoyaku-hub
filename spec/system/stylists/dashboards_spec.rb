# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/stylists/dashboards' do
  let(:default_shift_warning_text) { 'シフトの設定してください。' }
  let(:menu_registration_warning_text) { 'メニューを1つ以上登録してください。' }
  let(:prompt_title) { 'ご確認ください' }
  let(:this_month_prompt_text) { '現在予約が取れない状態です。今月分の受付設定をしてください。' }
  let(:next_month_prompt_text) { '来月の受付設定が未設定です。' }

  let(:stylist) { create(:user, :stylist) }

  def create_default_shifts(user)
    create(:working_hour, stylist: user, target_date: nil, day_of_week: nil)
    create(:reservation_limit, stylist: user, target_date: nil, time_slot: nil)
  end

  def create_menu(user)
    create(:menu, stylist: user)
  end

  before do
    sign_in stylist
  end

  context 'when default shifts are not configured and no menus are registered' do
    before do
      visit stylists_dashboard_path
    end

    it 'shows both default shift setup and menu registration warnings' do
      expect(page).to have_text(default_shift_warning_text)
      expect(page).to have_text(menu_registration_warning_text)
    end
  end

  context 'when only default shifts are not configured (menus are registered)' do
    before do
      create_menu(stylist)
      visit stylists_dashboard_path
    end

    it 'shows only the default shift setup warning' do
      expect(page).to have_text(default_shift_warning_text)
      expect(page).to have_no_text(menu_registration_warning_text)
    end
  end

  context 'when only menus are not registered (default shifts are configured)' do
    before do
      create_default_shifts(stylist)
      visit stylists_dashboard_path
    end

    it 'shows only the menu registration warning' do
      expect(page).to have_no_text(default_shift_warning_text)
      expect(page).to have_text(menu_registration_warning_text)
    end
  end

  context 'when both default shifts and menus are configured' do
    before do
      create_default_shifts(stylist)
      create_menu(stylist)
      visit stylists_dashboard_path
    end

    it 'does not show default shift setup or menu registration warnings' do
      expect(page).to have_no_text(default_shift_warning_text)
      expect(page).to have_no_text(menu_registration_warning_text)
    end
  end

  describe 'Shift Setup Prompts' do
    context "when this month's shifts are not configured" do
      before do
        allow(stylist).to receive_messages(current_month_shifts_configured?: false, next_month_shifts_configured?: true)
        visit stylists_dashboard_path
      end

      it 'displays the prompt for this month but not for the next month' do
        expect(page).to have_content(prompt_title)
        expect(page).to have_content(this_month_prompt_text)
        expect(page).to have_link '設定する',
          href: show_stylists_shift_settings_path(year: Date.current.year, month: Date.current.month)
        expect(page).to have_no_content(next_month_prompt_text)
      end
    end

    context "when next month's shifts are not configured" do
      let(:next_month_date) { Date.current.next_month }

      before do
        allow(stylist).to receive_messages(current_month_shifts_configured?: true, next_month_shifts_configured?: false)
      end

      it 'does not display the prompt for the next month when the date is on or before the 20th' do
        travel_to Date.new(Date.current.year, Date.current.month, 19) do
          visit stylists_dashboard_path
        end
        expect(page).to have_no_content(next_month_prompt_text)
        expect(page).to have_no_content(prompt_title)
      end

      it 'displays the prompt for the next month when the date is after the 20th' do
        travel_to Date.new(Date.current.year, Date.current.month, 21) do
          visit stylists_dashboard_path
        end
        expect(page).to have_content(prompt_title)
        expect(page).to have_content(next_month_prompt_text)
        expect(page).to have_link '設定する',
          href: show_stylists_shift_settings_path(year: next_month_date.year, month: next_month_date.month)
        expect(page).to have_no_content(this_month_prompt_text)
      end
    end

    context "when both this month's and next month's shifts are configured" do
      before do
        allow(stylist).to receive_messages(current_month_shifts_configured?: true, next_month_shifts_configured?: true)
        travel_to Date.new(Date.current.year, Date.current.month, 21) do
          visit stylists_dashboard_path
        end
      end

      it 'does not display any shift setup prompts' do
        expect(page).to have_no_content(prompt_title)
        expect(page).to have_no_content(this_month_prompt_text)
        expect(page).to have_no_content(next_month_prompt_text)
      end
    end

    context 'when both months are unconfigured and the date is after the 20th' do
      before do
        allow(stylist).to receive_messages(current_month_shifts_configured?: false,
          next_month_shifts_configured?: false)
        travel_to Date.new(Date.current.year, Date.current.month, 21) do
          visit stylists_dashboard_path
        end
      end

      it 'displays prompts for both this month and the next month' do
        expect(page).to have_content(prompt_title)
        expect(page).to have_content(this_month_prompt_text)
        expect(page).to have_content(next_month_prompt_text)
      end
    end
  end
end
