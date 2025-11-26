# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists Customer Search' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:stylist) do
    create(:user, role: :stylist,
      family_name: '美容師', given_name: '太郎',
      email: 'stylist@example.com', password: 'password', password_confirmation: 'password')
  end

  let!(:yamada_customer) do
    create(:user, role: :customer,
      family_name: '山田', given_name: '太郎',
      family_name_kana: 'ヤマダ', given_name_kana: 'タロウ',
      date_of_birth: 30.years.ago.to_date)
  end

  let!(:sato_customer) do
    create(:user, role: :customer,
      family_name: '佐藤', given_name: '花子',
      family_name_kana: 'サトウ', given_name_kana: 'ハナコ',
      date_of_birth: 25.years.ago.to_date)
  end

  let!(:tanaka_customer) do
    create(:user, role: :customer,
      family_name: '田中', given_name: '次郎',
      family_name_kana: 'タナカ', given_name_kana: 'ジロウ',
      date_of_birth: 35.years.ago.to_date)
  end

  let(:other_stylist) { create(:user, role: :stylist) }
  let(:menu) { create(:menu, stylist: stylist) }
  let(:other_menu) { create(:menu, stylist: other_stylist) }

  before do
    target_dates = [2.months.ago.to_date, 1.month.ago.to_date, Date.current]
    target_dates.each do |target_date|
      [stylist, other_stylist].each do |s|
        create(:working_hour,
          stylist: s,
          target_date: target_date,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))

        start_slot_index = (Time.zone.parse('09:00').hour * 2)
        end_slot_index = (Time.zone.parse('18:00').hour * 2)

        (start_slot_index...end_slot_index).each do |slot_idx|
          create(:reservation_limit,
            stylist: s,
            target_date: target_date,
            time_slot: slot_idx,
            max_reservations: 1)
        end
      end
    end

    create(:reservation, customer: yamada_customer, stylist: stylist, status: :paid,
      menu_ids: [menu.id], start_date_str: 2.months.ago.to_date.to_s, start_time_str: '10:00')
    create(:reservation, customer: sato_customer, stylist: stylist, status: :paid,
      menu_ids: [menu.id], start_date_str: 1.month.ago.to_date.to_s, start_time_str: '10:00')

    create(:reservation, customer: tanaka_customer, stylist: other_stylist, status: :paid,
      menu_ids: [other_menu.id], start_date_str: Date.current.to_s, start_time_str: '10:00')

    login_as_stylist
  end

  def login_as_stylist
    visit new_user_session_path
    fill_in 'user_email', with: stylist.email
    fill_in 'user_password', with: 'password'
    click_on 'ログイン'

    expect(page).to have_current_path(stylists_dashboard_path)
  end

  describe 'Customer list page' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'displays customer search interface' do
      visit stylists_customers_path

      expect(page).to have_content('顧客一覧')
      expect(page).to have_field('query', placeholder: '名前またはカタカナで検索...')
    end

    it 'displays stylists customers only' do
      visit stylists_customers_path

      expect(page).to have_content('山田 太郎')
      expect(page).to have_content('佐藤 花子')
      expect(page).to have_content('ヤマダ タロウ')
      expect(page).to have_content('サトウ ハナコ')

      expect(page).to have_no_content('田中 次郎')
    end

    it 'displays customer count' do
      visit stylists_customers_path
      expect(page).to have_content('2件の顧客が見つかりました')
    end

    it 'displays detail and carte buttons for each customer' do
      visit stylists_customers_path

      within 'tr', text: '山田 太郎' do
        expect(page).to have_link('詳細')
        expect(page).to have_link('カルテ')
      end
    end
  end

  describe 'Customer search functionality' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    before { visit stylists_customers_path }

    it 'searches by family name' do
      fill_in 'query', with: '山田'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('山田 太郎')
      expect(page).to have_no_content('佐藤 花子')
      expect(page).to have_content('1件の顧客が見つかりました')
    end

    it 'searches by given name' do
      fill_in 'query', with: '花子'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('佐藤 花子')
      expect(page).to have_no_content('山田 太郎')
    end

    it 'searches by family name kana' do
      fill_in 'query', with: 'ヤマダ'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('山田 太郎')
      expect(page).to have_no_content('佐藤 花子')
    end

    it 'searches by given name kana' do
      fill_in 'query', with: 'ハナコ'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('佐藤 花子')
      expect(page).to have_no_content('山田 太郎')
    end

    it 'searches by partial match' do
      fill_in 'query', with: '田'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('山田 太郎')
      expect(page).to have_no_content('佐藤 花子')
    end

    it 'shows no results message when no match found' do
      fill_in 'query', with: '存在しない名前'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('「存在しない名前」に一致する顧客はいません')
      expect(page).to have_content('検索キーワードを変更してみてください')
    end

    it 'provides clear search functionality' do
      fill_in 'query', with: '山田'
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('山田 太郎')
      expect(page).to have_content('1件の顧客が見つかりました')

      visit stylists_customers_path

      expect(page).to have_content('山田 太郎')
      expect(page).to have_content('佐藤 花子')
      expect(page).to have_content('2件の顧客が見つかりました')
    end

    it 'handles XSS attempts safely' do
      malicious_input = '<script>alert("XSS")</script>'
      fill_in 'query', with: malicious_input
      find('input[name="query"]').native.send_keys(:return)

      expect(page).to have_content('「<script>alert("XSS")</script>」に一致する顧客はいません')
    end
  end

  describe 'Customer detail page' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'displays customer details when clicking detail button' do
      visit stylists_customers_path

      within 'tr', text: '山田 太郎' do
        click_on '詳細'
      end

      expect(page).to have_content('顧客詳細')
      expect(page).to have_content('山田 太郎')
      expect(page).to have_content('ヤマダ タロウ')
      expect(page).to have_content('30歳')
    end

    it 'displays visit information' do
      visit stylists_customer_path(yamada_customer)

      expect(page).to have_content('来店データ')
      expect(page).to have_content('初回来店日')
      expect(page).to have_content('最終来店日')
      expect(page).to have_content('来店回数')
      expect(page).to have_content('来店周期')
    end

    it 'provides navigation back to customer list' do
      visit stylists_customer_path(yamada_customer)

      expect(page).to have_link('一覧に戻る')
      click_on '一覧に戻る'

      expect(page).to have_content('顧客一覧')
    end

    it 'provides carte access' do
      visit stylists_customer_path(yamada_customer)

      expect(page).to have_link('カルテを見る')
    end
  end

  describe 'Empty state' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    before do
      Reservation.destroy_all
      visit stylists_customers_path
    end

    it 'shows appropriate message when no customers exist' do
      expect(page).to have_content('顧客がまだ登録されていません')
      expect(page).to have_content('新規登録するか、お客様からの予約をお待ちください')
    end
  end

  describe 'Access control' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'prevents access from non-stylist users' do
      using_session('guest') do
        visit stylists_customers_path

        expect(page).to have_current_path(new_user_session_path)
        expect(page).to have_no_content('顧客一覧')
      end
    end

    it 'prevents access to other stylists customers' do
      visit stylists_customer_path(tanaka_customer)
      expect(page).to have_content('ActiveRecord::RecordNotFound')
    end
  end
end
