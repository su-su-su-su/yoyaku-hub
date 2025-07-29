# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::CustomerReservations', :js do # rubocop:disable Metrics/BlockLength
  let(:stylist) { create(:user, role: :stylist) }
  let(:customer) do
    create(:user, role: :customer,
      family_name: '山田', given_name: '太郎',
      family_name_kana: 'ヤマダ', given_name_kana: 'タロウ')
  end
  let(:stylist_created_customer) do
    create(:user, role: :customer, created_by_stylist_id: stylist.id,
      family_name: '田中', given_name: '次郎',
      family_name_kana: 'タナカ', given_name_kana: 'ジロウ')
  end
  let(:cut_menu) { create(:menu, stylist: stylist, name: 'カット', duration: 60, price: 3000) }
  let(:color_menu) { create(:menu, stylist: stylist, name: 'カラー', duration: 90, price: 5000) }

  before do # rubocop:disable Metrics/BlockLength
    login_as(stylist, scope: :user)

    [Date.current, 1.day.ago.to_date].each do |target_date|
      create(:working_hour,
        stylist: stylist,
        target_date: target_date,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))

      max_reservations = target_date == Date.current ? 2 : 1

      (18..35).each do |slot|
        create(:reservation_limit,
          stylist: stylist,
          target_date: target_date,
          time_slot: slot,
          max_reservations: max_reservations)
      end
    end

    yesterday_11am = 1.day.ago.beginning_of_day + 11.hours

    cut_menu
    color_menu

    reservation = Reservation.new(
      customer: customer,
      stylist: stylist,
      start_at: yesterday_11am,
      end_at: yesterday_11am + 1.hour,
      status: :paid
    )
    reservation.menu_ids = [cut_menu.id]
    reservation.save!(validate: false)

    stylist_created_customer
  end

  describe 'reservation creation from weekly schedule' do
    it 'allows creating reservation from empty slot' do
      visit stylists_weekly_schedules_path(start_date: Date.current.strftime('%Y-%m-%d'))

      within('tbody') do
        first('td.cursor-pointer').click
      end

      expect(page).to have_content('お客様の予約登録')
      expect(page).to have_content("予約日時: #{Date.current.strftime('%Y年%m月%d日')}")
    end
  end

  describe 'reservation creation from daily schedule' do
    it 'allows creating reservation from empty slot' do
      visit stylists_schedules_path(date: Date.current.strftime('%Y-%m-%d'))
      within('tbody') do
        first('td.cursor-pointer').click
      end

      expect(page).to have_content('お客様の予約登録')
      expect(page).to have_content("予約日時: #{Date.current.strftime('%Y年%m月%d日')}")
    end
  end

  describe 'customer search functionality' do # rubocop:disable Metrics/BlockLength
    before do
      visit new_stylists_customer_reservation_path(
        date: Date.current.strftime('%Y-%m-%d'),
        time_str: '10:00'
      )
    end

    it 'can search and select customer' do
      fill_in 'customer_search', with: '山田'

      expect(page).to have_content('山田 太郎', wait: 5)
      expect(page).to have_content('ヤマダ タロウ')

      within('.customer-list') do
        find('.customer-item', text: '山田 太郎').click
      end

      expect(page).to have_content('山田 太郎')
      expect(page).to have_button('変更')

      expect(page).to have_no_field('customer_search')
    end

    it 'can clear selection and search again' do
      fill_in 'customer_search', with: '山田'
      expect(page).to have_content('山田 太郎', wait: 5)
      within('.customer-list') do
        find('.customer-item', text: '山田 太郎').click
      end

      click_on '変更'

      expect(page).to have_field('customer_search')
      expect(page).to have_no_content('選択された顧客')

      fill_in 'customer_search', with: '田中'
      expect(page).to have_content('田中 次郎', wait: 5)
    end

    it 'shows message when no search results found' do
      fill_in 'customer_search', with: '存在しない名前'

      expect(page).to have_content('該当するお客様が見つかりませんでした', wait: 5)
    end
  end

  describe 'reservation creation' do # rubocop:disable Metrics/BlockLength
    before do
      visit new_stylists_customer_reservation_path(
        date: Date.current.strftime('%Y-%m-%d'),
        time_str: '10:00'
      )
    end

    it 'successfully creates reservation' do
      fill_in 'customer_search', with: '山田'
      expect(page).to have_content('山田 太郎', wait: 5)
      within('.customer-list') do
        find('.customer-item', text: '山田 太郎').click
      end

      check 'カット'
      check 'カラー'

      click_on '予約を登録'

      expect(page).to have_content('予約を登録しました')
      expect(page).to have_current_path(stylists_schedules_path(date: Date.current.strftime('%Y-%m-%d')))

      reservation = Reservation.last
      expect(reservation.customer).to eq(customer)
      expect(reservation.stylist).to eq(stylist)
      expect(reservation.menus).to contain_exactly(cut_menu, color_menu)
    end

    it 'shows error when customer not selected' do
      check 'カット'

      click_on '予約を登録'

      expect(page).to have_content('お客様を選択してください')
      expect(page).to have_no_content('予約を登録しました')
    end

    it 'shows error when menu not selected' do
      fill_in 'customer_search', with: '山田'
      expect(page).to have_content('山田 太郎', wait: 5)
      within('.customer-list') do
        find('.customer-item', text: '山田 太郎').click
      end

      click_on '予約を登録'

      expect(page).to have_content('は1つ以上選択してください')
      expect(page).to have_no_content('予約を登録しました')
    end
  end

  describe 'UI display' do
    before do
      visit new_stylists_customer_reservation_path(
        date: Date.current.strftime('%Y-%m-%d'),
        time_str: '10:00'
      )
    end

    it 'displays reservation date and time correctly' do
      expect(page).to have_content("予約日時: #{Date.current.strftime('%Y年%m月%d日')} 10:00")
    end

    it 'displays menu list' do
      expect(page).to have_content('カット (60分, ¥3,000)')
      expect(page).to have_content('カラー (90分, ¥5,000)')
    end

    it 'displays search placeholder' do
      expect(page).to have_field('customer_search', placeholder: 'お客様を検索')
    end
  end
end
