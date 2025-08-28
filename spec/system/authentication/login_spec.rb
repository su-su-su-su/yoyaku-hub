# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'User login' do
  let!(:customer) { create(:user, :customer) }
  let!(:stylist) { create(:user, :stylist) }

  context 'when logging in as a customer' do
    it 'allows login with valid credentials' do
      visit new_user_session_path

      fill_in 'user_email', with: customer.email
      fill_in 'user_password', with: 'testtest'
      click_on 'ログイン'

      expect(page).to have_css('#toast-container .toast-message', text: 'ログインしました')
      expect(page).to have_current_path('/customers/dashboard', url: false)
    end

    it 'shows error with invalid credentials' do
      visit new_user_session_path

      fill_in 'user_email', with: customer.email
      fill_in 'user_password', with: 'wrong_password'

      click_on 'ログイン'

      expect(page).to have_current_path('/login', url: false)
      expect(page).to have_css('#toast-container .toast-message', text: 'メールアドレスまたはパスワードが違います。')
      expect(page).to have_field('user_email')
      expect(page).to have_field('user_password')
    end
  end

  context 'when logging in as a stylist' do
    it 'allows login with valid credentials' do
      visit new_user_session_path

      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'testtest'

      click_on 'ログイン'

      expect(page).to have_css('#toast-container .toast-message', text: 'ログインしました')
      expect(page).to have_current_path('/stylists/dashboard', url: false)
    end
  end

  context 'when logging out' do
    it 'successfully logs out a customer and redirects to the login page' do
      sign_in customer
      visit customers_dashboard_path

      first('.dropdown .btn-ghost.btn-circle').click
      click_on 'ログアウト'

      expect(page).to have_css('#toast-container .toast-message', text: 'ログアウトしました。')

      expect(page).to have_current_path(new_user_session_path, ignore_query: true)
    end
  end

  context 'when already logged in' do
    it 'allows customer to access customer dashboard' do
      customer = create(:user, :customer)
      sign_in customer
      visit '/customers/dashboard'

      expect(page).to have_current_path('/customers/dashboard', url: false)
      expect(page).to have_css('.navbar')
      expect(page).to have_css('.link-item')
    end

    it 'allows stylist to access stylist dashboard' do
      stylist = create(:user, :stylist)
      sign_in stylist
      visit '/stylists/dashboard'

      expect(page).to have_current_path('/stylists/dashboard', url: false)
      expect(page).to have_content('予約表')
      expect(page).to have_content('メニュー管理')
      expect(page).to have_content('シフト管理')
    end

    it 'prevents customer from accessing stylist dashboard' do
      customer = create(:user, :customer)
      sign_in customer
      visit '/stylists/dashboard'

      expect(page).to have_current_path('/', url: false)
      expect(page).to have_content('YOYAKU HUB')
    end

    it 'prevents stylist from accessing customer dashboard' do
      stylist = create(:user, :stylist)
      sign_in stylist
      visit '/customers/dashboard'

      expect(page).to have_current_path('/', url: false)
      expect(page).to have_content('YOYAKU HUB')
    end
  end
end
# rubocop:enable Metrics/BlockLength
