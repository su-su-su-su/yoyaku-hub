# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::CustomerReservations' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:stylist) { create(:user, role: :stylist) }
  let(:customer) do
    create(:user, role: :customer,
      family_name: '山田', given_name: '太郎',
      family_name_kana: 'ヤマダ', given_name_kana: 'タロウ')
  end
  let(:other_stylist) { create(:user, role: :stylist) }
  let(:other_stylist_customer) do
    create(:user, role: :customer,
      family_name: '佐藤', given_name: '花子',
      family_name_kana: 'サトウ', given_name_kana: 'ハナコ',
      created_by_stylist_id: other_stylist.id)
  end
  let(:stylist_created_customer) do
    create(:user, role: :customer, created_by_stylist_id: stylist.id,
      family_name: '田中', given_name: '次郎',
      family_name_kana: 'タナカ', given_name_kana: 'ジロウ')
  end
  let(:cut_menu) { create(:menu, stylist: stylist, name: 'カット', duration: 60, price: 3000) }
  let(:color_menu) { create(:menu, stylist: stylist, name: 'カラー', duration: 90, price: 5000) }
  let(:date) { Date.current.strftime('%Y-%m-%d') }
  let(:time_str) { '10:00' }

  before do
    sign_in stylist

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

  describe 'GET /stylists/customer_reservations/new' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when successful' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'displays reservation creation form' do
        get new_stylists_customer_reservation_path, params: { date: date, time_str: time_str }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('お客様の予約登録')
        expect(response.body).to include("予約日時: #{Date.parse(date).strftime('%Y年%m月%d日')} #{time_str}")
      end

      it 'does not display customer list without search' do
        get new_stylists_customer_reservation_path, params: { date: date, time_str: time_str }

        expect(response.body).not_to include('山田 太郎')
        expect(response.body).not_to include('田中 次郎')
      end

      it 'displays matching customers when search query is present' do
        get new_stylists_customer_reservation_path,
          params: { date: date, time_str: time_str, customer_search: '山田' }

        expect(response.body).to include('山田 太郎')
        expect(response.body).to include('ヤマダ タロウ')
      end

      it 'includes stylist-created customers in search results' do
        get new_stylists_customer_reservation_path,
          params: { date: date, time_str: time_str, customer_search: '田中' }

        expect(response.body).to include('田中 次郎')
        expect(response.body).to include('タナカ ジロウ')
      end

      it 'displays message when no search results found' do
        get new_stylists_customer_reservation_path,
          params: { date: date, time_str: time_str, customer_search: '存在しない' }

        expect(response.body).to include('該当するお客様が見つかりませんでした')
      end
    end

    context 'when Turbo Frame request' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'returns only partial template' do
        get new_stylists_customer_reservation_path,
          params: { date: date, time_str: time_str, customer_search: '山田' },
          headers: { 'Turbo-Frame' => 'customer_search_results' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('山田 太郎')
        expect(response.body).not_to include('お客様の予約登録')
      end
    end
  end

  describe 'POST /stylists/customer_reservations' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when successful' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'creates reservation and redirects to schedule' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: customer.id,
          menu_ids: [cut_menu.id, color_menu.id]
        }

        expect(response).to redirect_to(stylists_schedules_path(date: date))
        expect(flash[:notice]).to eq(I18n.t('stylists.reservations.created'))

        reservation = Reservation.last
        expect(reservation.customer).to eq(customer)
        expect(reservation.stylist).to eq(stylist)
        expect(reservation.menus).to contain_exactly(cut_menu, color_menu)
      end

      it 'can create reservation for stylist-created customer' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: stylist_created_customer.id,
          menu_ids: [cut_menu.id]
        }

        expect(response).to redirect_to(stylists_schedules_path(date: date))
        expect(Reservation.last.customer).to eq(stylist_created_customer)
      end
    end

    context 'when validation error' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'shows error when customer not selected' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: '',
          menu_ids: [cut_menu.id]
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('お客様を選択してください')
      end

      it 'shows error when menu not selected' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: customer.id,
          menu_ids: []
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('は1つ以上選択してください')
      end

      it 'cannot create reservation for other stylists customers' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: other_stylist_customer.id,
          menu_ids: [cut_menu.id]
        }

        expect(response).to have_http_status(:not_found)
      end

      it 'shows error when outside business hours' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: '06:00',
          customer_id: customer.id,
          menu_ids: [cut_menu.id]
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('営業時間より早い')
      end
    end

    context 'when unauthorized' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      before { sign_out stylist }

      it 'redirects to login page' do
        post stylists_customer_reservations_path, params: {
          date: date,
          time_str: time_str,
          customer_id: customer.id,
          menu_ids: [cut_menu.id]
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
