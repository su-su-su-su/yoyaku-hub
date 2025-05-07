# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OmniAuth Google Authentication' do
  describe 'User logs in via Google' do
    context 'when the user is new and registers as a customer' do
      before do
        mock_google_auth_hash(email: 'new.customer@example.com', first_name: '新規', last_name: '顧客')
        visit new_customer_registration_path
        click_link_or_button 'お客様 新規登録'
      end

      it 'successfully creates a customer and redirects to profile edit' do
        expect(page).to have_content I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
        new_user = User.find_by(email: 'new.customer@example.com')
        expect(new_user).to be_present
        expect(new_user.role).to eq('customer')
        expect(page).to have_current_path(edit_customers_profile_path)
      end
    end

    context 'when the user is new and registers as a stylist' do
      before do
        mock_google_auth_hash(email: 'new.stylist@example.com', first_name: '新規', last_name: '美容師')
        visit new_stylist_registration_path
        click_link_or_button '美容師 新規登録'
      end

      it 'successfully creates a stylist and redirects to profile edit' do
        expect(page).to have_content I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
        new_user = User.find_by(email: 'new.stylist@example.com')
        expect(new_user).to be_present
        expect(new_user.role).to eq('stylist')
        expect(page).to have_current_path(edit_stylists_profile_path)
      end
    end

    context 'when an existing user logs in from the login page' do
      let!(:existing_user) do
        create(:user, :customer, provider: 'google_oauth2', uid: '123545', email: 'exists@example.com', family_name: '田中', given_name: '太郎',
          family_name_kana: 'タナカ', given_name_kana: 'タロウ', gender: 0, date_of_birth: '1990-01-01')
      end

      before do
        mock_google_auth_hash(email: existing_user.email, uid: existing_user.uid,
          first_name: existing_user.given_name, last_name: existing_user.family_name)
        visit new_user_session_path
        click_link_or_button 'Googleでログイン'
      end

      it 'logs in the existing user and redirects to their dashboard' do
        expect(page).to have_content I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
        expect(page).to have_current_path(customers_dashboard_path)
      end
    end

    context 'when an unregistered user tries to log in from the login page' do
      before do
        mock_google_auth_hash(email: 'unregistered@example.com')
        visit new_user_session_path
        click_link_or_button 'Googleでログイン'
      end

      it 'redirects to the login page with an "account not found" message' do
        expect(page).to have_current_path(new_user_session_path)
        expect(page).to have_content I18n.t('alerts.omniauth_account_not_found')
      end
    end

    context 'when Google authentication fails' do
      before do
        mock_google_auth_invalid
        visit new_user_session_path
        click_link_or_button 'Googleでログイン'
      end

      it 'redirects to the login page with a failure message' do
        expect(page).to have_current_path(new_user_session_path)
        expect(page).to have_content I18n.t('alerts.login_failed')
      end
    end
  end
end
