# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylist Menu Management' do
  let(:stylist) { create(:user, :stylist) }
  let(:customer) { create(:user, :customer) }

  describe 'Access restrictions' do
    it 'redirects to login page when not logged in' do
      visit menus_settings_path
      expect(page).to have_current_path(new_user_session_path)
    end

    it 'prevents access for customer users' do
      sign_in customer
      visit menus_settings_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content('アクセス権限がありません')
    end
  end

  describe 'Menu list display' do
    before do
      sign_in stylist
      create(:menu, :cut, stylist: stylist, name: 'カット', price: 6600, duration: 60, sort_order: 1)
      create(:menu, :color, stylist: stylist, name: 'カラー', price: 8800, duration: 90, sort_order: 2, is_active: false)
      visit menus_settings_path
    end

    it 'displays the menu list' do
      expect(page).to have_text('メニュー管理')
      expect(page).to have_text('カット')
      expect(page).to have_text('カラー')
      expect(page).to have_text('¥6,600')
      expect(page).to have_text('¥8,800')
      expect(page).to have_text('60分')
      expect(page).to have_text('90分')
    end

    it 'displays the publication status of menus' do
      expect(page).to have_text('掲載中')
      expect(page).to have_text('非掲載')
    end
  end

  describe 'Creating a new menu' do
    before do
      sign_in stylist
      visit menus_settings_path
      click_on '新規メニュー登録'
    end

    context 'with valid data' do
      it 'creates a new menu', :js do
        within('turbo-frame#new_menu') do
          fill_in 'メニュー名', with: 'トリートメント'
          fill_in 'menu[price]', with: '5500'
          select '60分', from: 'menu[duration]'
          fill_in '備考', with: '髪質改善トリートメント'
          check 'トリートメント'
          click_on '登録する'
        end

        expect(page).to have_text('トリートメント')
        expect(page).to have_text('¥5,500')
        expect(page).to have_text('60分')
        expect(page).to have_text('髪質改善トリートメント')
        expect(stylist.menus.count).to eq(1)
      end
    end

    context 'with invalid data' do
      it 'displays error messages', :js do
        within('turbo-frame#new_menu') do
          fill_in 'メニュー名', with: ''
          fill_in 'menu[price]', with: '-1000'
          click_on '登録する'
        end

        expect(page).to have_text('名前を入力してください')
        expect(page).to have_text('価格は0以上の値にしてください')
        expect(stylist.menus.count).to eq(0)
      end
    end
  end

  describe 'Editing a menu' do
    let!(:menu) { create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60) }

    before do
      sign_in stylist
      visit menus_settings_path
      within("turbo-frame##{dom_id(menu)}") do
        click_on '編集'
      end
    end

    context 'with valid data' do
      it 'updates the menu', :js do
        within("turbo-frame##{dom_id(menu)}") do
          fill_in 'メニュー名', with: 'ベーシックカット'
          fill_in 'menu[price]', with: '7700'
          select '60分', from: 'menu[duration]'
          click_on '更新する'
        end

        expect(page).to have_text('ベーシックカット')
        expect(page).to have_text('¥7,700')
        expect(page).to have_text('60分')
        expect(menu.reload.name).to eq('ベーシックカット')
      end
    end

    context 'with invalid data' do
      it 'does not update the menu', :js do
        within("turbo-frame##{dom_id(menu)}") do
          fill_in 'メニュー名', with: ''
          click_on '更新する'
        end
        expect(menu.reload.name).to eq('カット')
      end
    end
  end

  describe 'Menu sort order' do
    let!(:cut_menu) { create(:menu, stylist: stylist, name: 'カット', sort_order: 1) }
    let!(:color_menu) { create(:menu, stylist: stylist, name: 'カラー', sort_order: 2) }
    let!(:perm_menu) { create(:menu, stylist: stylist, name: 'パーマ', sort_order: 3) }

    before do
      sign_in stylist
      visit menus_settings_path
      within("turbo-frame##{dom_id(perm_menu)}") do
        click_on '編集'
      end
    end

    it 'changes the sort order', :js do
      within("turbo-frame##{dom_id(perm_menu)}") do
        fill_in 'menu[sort_order]', with: '1'
        click_on '更新する'
      end

      visit menus_settings_path
      menu_elements = all('[data-testid="stylist-menu-item"]')
      expect(menu_elements[0]).to have_text('パーマ')
      expect(menu_elements[1]).to have_text('カット')
      expect(menu_elements[2]).to have_text('カラー')

      expect(cut_menu.reload.sort_order).to eq(2)
      expect(color_menu.reload.sort_order).to eq(3)
      expect(perm_menu.reload.sort_order).to eq(1)
    end
  end

  describe 'Menu creation limit' do
    before do
      sign_in stylist
      create_list(:menu, Menu::MAX_MENUS_PER_STYLIST, stylist: stylist)
      visit menus_settings_path
      click_on '新規メニュー登録'
    end

    it 'displays an error when reaching the menu creation limit', :js do
      within('turbo-frame#new_menu') do
        fill_in 'メニュー名', with: '上限超過メニュー'
        fill_in 'menu[price]', with: '1000'
        select '30分', from: 'menu[duration]'
        click_on '登録する'
      end

      expect(page).to have_text("メニューは最大#{Menu::MAX_MENUS_PER_STYLIST}件までです")
      expect(stylist.menus.count).to eq(Menu::MAX_MENUS_PER_STYLIST)
    end
  end
end
# rubocop:enable Metrics/BlockLength
