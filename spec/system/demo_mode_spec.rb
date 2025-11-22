# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'デモモード機能' do
  include Rails.application.routes.url_helpers

  before do
    ENV['ENABLE_DEMO_MODE'] = 'true'
    User.where("email LIKE 'demo_%@example.com'").destroy_all
  end

  after do
    User.where("email LIKE 'demo_%@example.com'").destroy_all
    ENV['ENABLE_DEMO_MODE'] = nil
  end

  describe 'デモページ' do
    it 'デモページが表示される' do
      visit '/demo'

      expect(page).to have_content 'YOYAKU HUB デモ体験'
      expect(page).to have_content '実際の機能を今すぐ、手軽にお試しいただけます'
      expect(page).to have_link 'スタイリストとして始める'
      expect(page).to have_link 'カスタマーとして始める'
    end

    it 'デモの特徴が正しく表示される' do
      visit '/demo'

      expect(page).to have_content 'デモ環境について'
      expect(page).to have_content '入力されたデータは一時的なものです'
    end
  end

  describe 'スタイリストデモ' do
    it 'スタイリストとして自動ログインできる' do
      visit '/stylists/dashboard?demo=stylist'

      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true
      stylist = User.where(role: :stylist).last
      expect(stylist).not_to be_nil
      expect(stylist.email).to match(/demo_stylist_.*@example.com/)
    end

    it 'メニューが自動作成される' do
      visit '/stylists/dashboard?demo=stylist'
      visit menus_settings_path

      expect(page).to have_content 'カット'
      expect(page).to have_content 'カラーリング'
      expect(page).to have_content 'パーマ'
    end

    it 'プロフィール編集ができない' do
      visit '/stylists/dashboard?demo=stylist'
      visit edit_stylists_profile_path

      fill_in '性', with: '変更後'
      click_on '登録'

      expect(page).to have_content 'デモユーザーの情報は変更できません。'
      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true
    end
  end

  describe 'カスタマーデモ' do
    it 'カスタマーとして自動ログインできる' do
      visit '/customers/dashboard?demo=customer'

      expect(page).to have_current_path customers_dashboard_path, ignore_query: true
      customer = User.where(role: :customer).last
      expect(customer).not_to be_nil
      expect(customer.email).to match(/demo_customer_.*@example.com/)
    end

    it '同じセッションのデモスタイリストのみ表示される' do
      visit '/customers/dashboard?demo=customer'
      visit customers_stylists_index_path

      expect(page).to have_css('.stylist-item')
    end
  end

  describe 'デモモードの切り替え' do
    it 'スタイリストからカスタマーに切り替えられる' do
      visit '/stylists/dashboard?demo=stylist'
      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true

      visit '/customers/dashboard?demo=customer'
      expect(page).to have_current_path customers_dashboard_path, ignore_query: true
    end

    it '異なるユーザーで再度ログインできる' do
      visit '/customers/dashboard?demo=customer'
      expect(page).to have_current_path customers_dashboard_path, ignore_query: true

      visit '/stylists/dashboard?demo=stylist'
      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true
    end
  end

  describe 'セッション独立性', :js do
    it '異なるセッションで独立したデモ環境が作成される' do
      visit '/stylists/dashboard?demo=stylist'
      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true
      stylist1 = User.where(role: :stylist).last

      page.driver.browser.manage.delete_all_cookies

      visit '/stylists/dashboard?demo=stylist'
      expect(page).to have_current_path stylists_dashboard_path, ignore_query: true
      stylist2 = User.where(role: :stylist).last

      expect(stylist1.email).not_to eq stylist2.email
      expect(User.where(role: :stylist, family_name: 'デモ').count).to eq 2
    end
  end

  describe '予約機能' do
    it 'デモカスタマーから予約が作成できる' do
      visit '/customers/dashboard?demo=customer'

      visit customers_stylists_index_path

      expect(page).to have_css('.stylist-item')
    end
  end

  describe 'デモモードが無効な場合' do
    before do
      ENV['ENABLE_DEMO_MODE'] = nil
    end

    it 'デモURLでアクセスしても通常のログインページにリダイレクトされる' do
      visit '/stylists/dashboard?demo=stylist'

      expect(page).to have_current_path new_user_session_path, ignore_query: true
      expect(page).to have_no_content 'デモ スタイリスト'
    end
  end
end
# rubocop:enable Metrics/BlockLength
