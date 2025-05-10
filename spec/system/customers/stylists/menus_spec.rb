# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customer menu viewing and selection' do
  let(:stylist) { create(:user, :stylist) }
  let(:customer) { create(:user, :customer) }
  let(:other_stylist) { create(:user, :stylist, email: 'other_stylist@example.com') }
  let(:non_stylist_user) { create(:user, :customer, email: 'another_customer@example.com') }
  let(:non_existing_stylist_id) { User.maximum(:id).to_i + 99 }

  context 'when viewing the stylist menu page' do
    before do
      create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60, is_active: true)
      create(:menu, stylist: stylist, name: 'カラー', price: 8800, duration: 90, is_active: true)
      create(:menu, stylist: stylist, name: '非公開メニュー', price: 5500, duration: 45, is_active: false)

      sign_in customer
      visit customers_stylist_menus_path(stylist)
    end

    it 'displays the stylist menu list' do
      expect(page).to have_text("#{stylist.family_name} #{stylist.given_name} さんのメニュー一覧")
      expect(page).to have_text('カット')
      expect(page).to have_text('カラー')
      expect(page).to have_text('¥6600')
      expect(page).to have_text('¥8800')
      expect(page).to have_text('60分')
      expect(page).to have_text('90分')
    end

    it 'does not display inactive menus' do
      expect(page).to have_no_text('非公開メニュー')
      expect(page).to have_no_text('¥5500')
      expect(page).to have_no_text('45分')
    end

    it 'allows selecting a menu and proceeding to the next step' do
      first('label.cs-menu-item').click

      click_on '日時を設定'

      expect(page).to have_current_path(/weekly/, url: true)
      expect(page).to have_content('日')
      expect(page).to have_content('月')
    end
  end

  context 'when trying to proceed without selecting a menu' do
    before do
      create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60, is_active: true)
      sign_in customer
      visit customers_stylist_menus_path(stylist)
    end

    it 'displays an error when trying to proceed without selecting a menu' do
      click_on '日時を設定'

      expect(page).to have_text(I18n.t('flash.menu_not_selected'))

      expect(page).to have_current_path(customers_stylist_menus_path(stylist))
    end
  end

  context 'when accessing the menu page with different authentication states' do
    it 'redirects to the login page when accessed without authentication' do
      visit customers_stylist_menus_path(stylist)

      expect(page).to have_current_path(new_user_session_path)
    end

    it 'redirects to the dashboard when accessing a non-stylist user page' do
      sign_in customer

      visit customers_stylist_menus_path(non_stylist_user)

      expect(page).to have_current_path(customers_dashboard_path)
    end
  end

  context 'when no menus are registered for the stylist' do
    before do
      sign_in customer
      visit customers_stylist_menus_path(stylist)
    end

    it 'displays an appropriate message when no menus are registered' do
      expect(page).to have_text('メニューが登録されていません。')

      expect(page).to have_no_button('日時を設定')
    end
  end

  context 'when navigating from the menu page' do
    before do
      create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60, is_active: true)
      sign_in customer
      visit customers_stylist_menus_path(stylist)
    end

    it 'back link functions correctly' do
      click_on '戻る'
      expect(page).to have_current_path(customers_stylists_index_path)
    end

    it 'user top page link functions correctly' do
      click_on 'ユーザートップページへ'
      expect(page).to have_current_path(customers_dashboard_path)
    end
  end

  context 'when multiple menus with different sort orders exist' do
    before do
      create(:menu, stylist: stylist, name: 'パーマ', price: 10_000, duration: 120, is_active: true, sort_order: 3)
      create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60, is_active: true, sort_order: 1)
      create(:menu, stylist: stylist, name: 'カラー', price: 8800, duration: 90, is_active: true, sort_order: 2)

      sign_in customer
      visit customers_stylist_menus_path(stylist)
    end

    it 'displays menus in sort_order sequence' do
      menu_names = page.all('.cs-menu-item h2').map(&:text)
      expect(menu_names).to eq(%w[カット カラー パーマ])
    end
  end

  describe 'Access Control and Error Handling for Menu Page' do
    context 'when a stylist views their own customer menu page (as preview)' do
      before do
        create_list(:menu, 2, stylist: stylist, is_active: true)
        sign_in stylist
        visit customers_stylist_menus_path(stylist)
      end

      it 'allows access and displays their own menus correctly' do
        expect(page).to have_current_path(customers_stylist_menus_path(stylist))
        expect(page).to have_text("#{stylist.family_name} #{stylist.given_name} さんのメニュー一覧")
        expect(page.all('.cs-menu-item').count).to eq(2)
      end
    end

    context 'when a stylist attempts to view another stylist\'s customer menu page' do
      before do
        sign_in stylist
        visit customers_stylist_menus_path(other_stylist)
      end

      it 'redirects to the stylist dashboard with an access denied alert' do
        expect(page).to have_current_path(stylists_dashboard_path)
        expect(page).to have_text(I18n.t('flash.customers.stylists.cannot_view_other_stylist_menus'))
      end
    end

    context 'when a customer attempts to view menus of a non-existent stylist' do
      before do
        sign_in customer
        visit customers_stylist_menus_path(non_existing_stylist_id)
      end

      it 'redirects to the customer dashboard with a stylist not found alert' do
        expect(page).to have_current_path(customers_dashboard_path)
        expect(page).to have_text(I18n.t('flash.customers.stylists.stylist_not_found'))
      end
    end

    context 'when a stylist attempts to view menus of a non-existent stylist' do
      before do
        sign_in stylist
        visit customers_stylist_menus_path(non_existing_stylist_id)
      end

      it 'redirects to the stylist dashboard with an invalid access alert' do
        expect(page).to have_current_path(stylists_dashboard_path)
        expect(page).to have_text(I18n.t('flash.customers.stylists.invalid_access'))
      end
    end

    context 'when a customer attempts to view menus of a user who is not a stylist' do
      before do
        sign_in customer
        visit customers_stylist_menus_path(non_stylist_user)
      end

      it 'redirects to the customer dashboard with a stylist not found alert' do
        expect(page).to have_current_path(customers_dashboard_path)
        expect(page).to have_text(I18n.t('flash.customers.stylists.stylist_not_found'))
      end
    end

    context 'when a stylist attempts to view menus of a user who is not a stylist' do
      before do
        sign_in stylist
        visit customers_stylist_menus_path(non_stylist_user)
      end

      it 'redirects to the stylist dashboard with an invalid access alert' do
        expect(page).to have_current_path(stylists_dashboard_path)
        expect(page).to have_text(I18n.t('flash.customers.stylists.invalid_access'))
      end
    end
  end
end
