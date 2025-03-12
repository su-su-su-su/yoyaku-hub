# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist reservation limit settings' do
  let(:stylist) { create(:user, role: :stylist) }

  describe 'Reservation limit configuration' do
    before do
      sign_in stylist
      visit stylists_shift_settings_path
    end

    it 'can access the reservation limit settings page' do
      expect(page).to have_current_path(stylists_shift_settings_path)
      expect(page).to have_content('受付可能数')
      expect(page).to have_css('form[action="/stylists/shift_settings/reservation_limits"]')
    end

    it 'can set new reservation limit' do
      expect(page).to have_select('reservation_limit_max_reservations')

      select '2', from: 'reservation_limit[max_reservations]'

      within('form[action="/stylists/shift_settings/reservation_limits"]') do
        click_on '設定'
      end

      expect(page).to have_content(I18n.t('stylists.shift_settings.reservation_limits.create_success'))

      limit = ReservationLimit.find_by(stylist_id: stylist.id)
      expect(limit).to be_present
      expect(limit.max_reservations).to eq 2

      expect(page).to have_select('reservation_limit[max_reservations]', selected: '2')
    end

    it 'can update existing reservation limit' do
      create(:reservation_limit, stylist: stylist, max_reservations: 1)

      visit stylists_shift_settings_path

      expect(page).to have_select('reservation_limit[max_reservations]', selected: '1')

      select '0', from: 'reservation_limit[max_reservations]'

      within('form[action="/stylists/shift_settings/reservation_limits"]') do
        click_on '設定'
      end

      expect(page).to have_content(I18n.t('stylists.shift_settings.reservation_limits.create_success'))

      limit = ReservationLimit.find_by(stylist_id: stylist.id)
      expect(limit).to be_present
      expect(limit.max_reservations).to eq 0

      expect(page).to have_select('reservation_limit[max_reservations]', selected: '0')
    end
  end

  describe 'Access restrictions' do
    it 'non-stylist users cannot access the settings page' do
      customer = create(:user, role: :customer)
      sign_in customer

      visit stylists_shift_settings_path

      expect(page).to have_no_current_path stylists_shift_settings_path, ignore_query: true
    end
  end
end
