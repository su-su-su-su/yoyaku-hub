# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User signup' do
  context 'when signing up as a customer' do
    it 'allows registration with valid information' do
      visit new_customer_registration_path

      fill_in 'user_email', with: 'customer@example.com'
      fill_in 'user_password', with: 'password123'
      fill_in 'user_password_confirmation', with: 'password123'

      click_on '登録'

      expect(page).to have_content('アカウント登録が完了しました')
      expect(page).to have_current_path('/customers/profile/edit', url: false)
    end

    it 'displays errors with invalid information' do
      visit new_customer_registration_path
      click_on '登録'

      expect(page).to have_content('エラー')
      expect(page).to have_field('user_email')
    end
  end

  context 'when signing up as a stylist' do
    it 'allows registration with valid information' do
      visit new_stylist_registration_path

      fill_in 'user_email', with: 'stylist@example.com'
      fill_in 'user_password', with: 'password123'
      fill_in 'user_password_confirmation', with: 'password123'

      click_on '登録'

      expect(page).to have_content('アカウント登録が完了しました')
      expect(page).to have_current_path('/stylists/profile/edit', url: false)
    end
  end
end
