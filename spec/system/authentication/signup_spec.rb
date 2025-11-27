# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'User signup' do
  context 'when signing up as a customer' do
    it 'allows registration with valid information' do
      visit new_customer_registration_path

      fill_in 'user_email', with: 'customer@example.com'
      fill_in 'user_password', with: 'password123'
      fill_in 'user_password_confirmation', with: 'password123'

      click_on '登録'

      expect(page).to have_css('h1', text: 'プロフィール編集')
      expect(page).to have_css('#toast-container .toast-message', text: 'アカウント登録が完了しました')
      expect(page).to have_current_path('/customers/profile/edit', url: false)
    end

    it 'displays errors with invalid information' do
      visit new_customer_registration_path

      # 有効なメールアドレスと短いパスワードを入力
      fill_in 'user_email', with: 'test@example.com'
      fill_in 'user_password', with: 'short'
      fill_in 'user_password_confirmation', with: 'short'

      click_on '登録'

      # パスワードが8文字未満のためエラーが表示される
      expect(page).to have_content('パスワードは8文字以上で入力してください')
    end
  end

  context 'when signing up as a stylist' do
    it 'allows registration with valid information and redirects to subscription' do
      visit new_stylist_registration_path

      fill_in 'user_email', with: 'stylist@example.com'
      fill_in 'user_password', with: 'password123'
      fill_in 'user_password_confirmation', with: 'password123'

      click_on '登録'

      expect(page).to have_css('#toast-container .toast-message', text: 'アカウント登録が完了しました')
      expect(page).to have_current_path('/subscription/new', url: false)
    end
  end
end
# rubocop:enable Metrics/BlockLength
