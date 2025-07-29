# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylists Customer Registration' do
  let(:stylist) { create(:user, :stylist) }
  let(:other_stylist) { create(:user, :stylist) }

  before do
    driven_by(:rack_test)
    sign_in stylist
  end

  describe 'Customer registration' do
    it 'allows stylist to register a new customer' do
      visit stylists_customers_path

      expect(page).to have_content('顧客一覧')
      click_on '新規顧客登録'

      expect(page).to have_content('顧客登録')

      fill_in 'user[family_name]', with: '田中'
      fill_in 'user[given_name]', with: '太郎'
      fill_in 'user[family_name_kana]', with: 'タナカ'
      fill_in 'user[given_name_kana]', with: 'タロウ'
      choose 'user_gender_male'
      fill_in 'user[email]', with: 'tanaka@example.com'

      click_on '登録'

      expect(page).to have_content('顧客を登録しました。')
      expect(page).to have_content('田中 太郎')
      expect(page).to have_content('タナカ タロウ')

      customer = User.last
      expect(customer.role).to eq('customer')
      expect(customer.created_by_stylist_id).to eq(stylist.id)
      expect(customer.email).to eq('tanaka@example.com')
    end

    it 'generates dummy email when email is blank' do
      visit new_stylists_customer_path

      fill_in 'user[family_name]', with: '山田'
      fill_in 'user[given_name]', with: '花子'
      fill_in 'user[family_name_kana]', with: 'ヤマダ'
      fill_in 'user[given_name_kana]', with: 'ハナコ'
      choose 'user_gender_female'

      click_on '登録'

      expect(page).to have_content('顧客を登録しました。')

      customer = User.last
      expect(customer.dummy_email?).to be true
      expect(customer.email).to match(/dummy_\d{14}_[a-zA-Z0-9]{8}@no-email-dummy\.invalid/)
    end

    it 'allows registration with minimal required fields' do
      visit new_stylists_customer_path

      fill_in 'user[family_name]', with: '佐藤'
      fill_in 'user[given_name]', with: '次郎'
      fill_in 'user[family_name_kana]', with: 'サトウ'
      fill_in 'user[given_name_kana]', with: 'ジロウ'
      choose 'user_gender_no_answer'

      click_on '登録'

      expect(page).to have_content('顧客を登録しました。')

      customer = User.last
      expect(customer.date_of_birth).to be_nil
      expect(customer.dummy_email?).to be true
    end

    it 'shows validation errors for missing required fields' do
      visit new_stylists_customer_path

      click_on '登録'

      expect(page).to have_content('エラーが発生しました。')
      expect(page).to have_content('顧客登録')
      expect(User.count).to eq(1)
    end

    it 'can cancel registration and return to customer list' do
      visit new_stylists_customer_path

      fill_in 'user[family_name]', with: '田中'
      click_on 'キャンセル'

      expect(page).to have_content('顧客一覧')
      expect(User.where(role: :customer).count).to eq(0)
    end
  end
  # rubocop:enable Metrics/BlockLength

  # rubocop:disable Metrics/BlockLength
  describe 'Customer editing' do
    let(:manual_customer) do
      create(:user, :customer,
        created_by_stylist_id: stylist.id,
        family_name: '元田中',
        given_name: '太郎',
        family_name_kana: 'モトタナカ',
        given_name_kana: 'タロウ',
        email: 'original@example.com')
    end

    let!(:other_manual_customer) do
      create(:user, :customer,
        created_by_stylist_id: other_stylist.id,
        family_name: '他人',
        given_name: '花子')
    end

    it 'allows editing own registered customers' do
      visit stylists_customer_path(manual_customer)

      expect(page).to have_content('元田中 太郎')
      expect(page).to have_link('顧客情報を編集')

      click_on '顧客情報を編集'

      expect(page).to have_content('顧客情報編集')
      expect(page).to have_field('user[family_name]', with: '元田中')
      expect(page).to have_field('user[email]', with: 'original@example.com')

      fill_in 'user[family_name]', with: '新田中'
      fill_in 'user[email]', with: 'updated@example.com'

      click_on '更新'

      expect(page).to have_content('顧客情報を更新しました。')
      expect(page).to have_content('新田中 太郎')

      manual_customer.reload
      expect(manual_customer.family_name).to eq('新田中')
      expect(manual_customer.email).to eq('updated@example.com')
    end

    it 'generates dummy email when email is cleared during update' do
      visit edit_stylists_customer_path(manual_customer)

      fill_in 'user[email]', with: ''
      click_on '更新'

      expect(page).to have_content('顧客情報を更新しました。')

      manual_customer.reload
      expect(manual_customer.dummy_email?).to be true
    end

    it 'does not show edit button for customers registered by other stylists' do
      visit stylists_customers_path
      expect(page).to have_no_content('他人 花子')
    end

    it 'prevents direct access to edit other stylist\'s customers' do
      visit edit_stylists_customer_path(other_manual_customer)

      expect(page).to have_content('この顧客の編集権限がありません。')
      expect(page).to have_content('顧客一覧')
    end

    it 'shows validation errors during update' do
      visit edit_stylists_customer_path(manual_customer)

      fill_in 'user[family_name]', with: ''
      fill_in 'user[given_name]', with: ''
      click_on '更新'

      expect(page).to have_content('エラーが発生しました。')
      expect(page).to have_content('顧客情報編集')

      manual_customer.reload
      expect(manual_customer.family_name).to eq('元田中')
    end

    it 'can cancel editing and return to customer detail' do
      visit edit_stylists_customer_path(manual_customer)

      fill_in 'user[family_name]', with: '変更済み'
      click_on 'キャンセル'

      expect(page).to have_content('顧客詳細')
      expect(page).to have_content('元田中 太郎')

      manual_customer.reload
      expect(manual_customer.family_name).to eq('元田中')
    end
  end
  # rubocop:enable Metrics/BlockLength

  # rubocop:disable Metrics/BlockLength
  describe 'Customer list integration' do
    let!(:reservation_customer) { create(:user, :customer, family_name: '予約', given_name: '顧客') }
    let!(:manual_customer) { nil } # rubocop:disable RSpec/LetSetup

    before do
      @manual_customer = create(:user, :customer,
        created_by_stylist_id: stylist.id,
        family_name: '手動',
        given_name: '顧客')
      menu = create(:menu, stylist: stylist)
      create(:working_hour,
        stylist: stylist,
        target_date: Date.current,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))

      start_slot_index = (Time.zone.parse('09:00').hour * 2)
      end_slot_index = (Time.zone.parse('18:00').hour * 2)

      (start_slot_index...end_slot_index).each do |slot_idx|
        create(:reservation_limit,
          stylist: stylist,
          target_date: Date.current,
          time_slot: slot_idx,
          max_reservations: 1)
      end

      create(:reservation,
        customer: reservation_customer,
        stylist: stylist,
        status: :paid,
        menu_ids: [menu.id],
        start_date_str: Date.current.to_s,
        start_time_str: '10:00')
    end

    it 'shows both reservation customers and manually registered customers' do
      visit stylists_customers_path

      expect(page).to have_content('予約 顧客')
      expect(page).to have_content('手動 顧客')

      click_on '詳細', match: :first

      if page.has_content?('手動 顧客')
        expect(page).to have_link('顧客情報を編集')
      else
        expect(page).to have_no_link('顧客情報を編集')
      end
    end

    it 'can search for manually registered customers' do
      visit stylists_customers_path

      fill_in 'query', with: '手動'
      find('.search-button').click

      expect(page).to have_content('手動 顧客')
      expect(page).to have_no_content('予約 顧客')
      expect(page).to have_content('1件の顧客が見つかりました')
    end
  end
  # rubocop:enable Metrics/BlockLength
end
