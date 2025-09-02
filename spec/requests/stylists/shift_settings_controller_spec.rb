# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylists::ShiftSettingsController', type: :request do
  let(:stylist) do
    create(:user, role: :stylist,
      family_name: '田中',
      given_name: '太郎',
      family_name_kana: 'タナカ',
      given_name_kana: 'タロウ',
      gender: 'male',
      date_of_birth: '1990-01-01')
  end

  let(:customer) do
    create(:user, role: :customer,
      family_name: '山田',
      given_name: '花子')
  end

  let(:current_year) { Time.zone.today.year }
  let(:current_month) { Time.zone.today.month }
  let(:target_date) { Date.new(current_year, current_month, 1) }

  before do
    sign_in stylist
    # スタイリストのデフォルト営業時間を設定（予約作成のバリデーションエラーを防ぐため）
    setup_default_working_hours
    setup_default_holidays
    setup_default_reservation_limits
  end

  def setup_default_working_hours
    # 平日（月〜金）
    (1..5).each do |wday|
      create(:working_hour,
        stylist:,
        day_of_week: wday,
        target_date: nil,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))
    end
    # 土曜日
    create(:working_hour,
      stylist:,
      day_of_week: 6,
      target_date: nil,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('17:00'))
    # 日曜日
    create(:working_hour,
      stylist:,
      day_of_week: 0,
      target_date: nil,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('17:00'))
    # 祝日
    create(:working_hour,
      stylist:,
      day_of_week: 7,
      target_date: nil,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('17:00'))
  end

  def setup_default_holidays
    # デフォルトでは休業日なし（必要に応じて個別に設定）
  end

  def setup_default_reservation_limits
    create(:reservation_limit,
      stylist:,
      target_date: nil,
      time_slot: nil,
      max_reservations: 2)
  end

  def setup_specific_date_working_hours(date, start_time: '09:00', end_time: '18:00')
    create(:working_hour,
      stylist:,
      target_date: date,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
    
    # その日の各時間スロットの予約上限も設定
    start_slot = Time.zone.parse(start_time).hour * 2
    end_slot = Time.zone.parse(end_time).hour * 2
    (start_slot...end_slot).each do |slot|
      create(:reservation_limit,
        stylist:,
        target_date: date,
        time_slot: slot,
        max_reservations: 2)
    end
  end

  describe 'GET #show' do
    context '予約がない月の場合' do
      it '空の予約配列が渡される' do
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        expect(response).to have_http_status(:ok)
        expect(assigns(:existing_reservations)).to eq([])
      end
    end

    context '予約がある月の場合' do
      before do
        # 特定の日付に営業時間を設定
        setup_specific_date_working_hours(target_date)
        setup_specific_date_working_hours(target_date + 4.days)
      end

      let!(:reservation1) do
        create(:reservation,
          stylist:,
          customer:,
          start_at: target_date.to_time.change(hour: 10),
          end_at: target_date.to_time.change(hour: 11),
          status: :before_visit)
      end

      let!(:reservation2) do
        create(:reservation,
          stylist:,
          customer: create(:user, role: :customer, family_name: '佐藤', given_name: '次郎'),
          start_at: (target_date + 4.days).to_time.change(hour: 14),
          end_at: (target_date + 4.days).to_time.change(hour: 15),
          status: :paid)
      end

      it '予約情報が正しい形式で渡される' do
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        expect(response).to have_http_status(:ok)
        
        reservations = assigns(:existing_reservations)
        expect(reservations).to be_an(Array)
        expect(reservations.size).to eq(2)
        
        # 1件目の予約を確認
        first_reservation = reservations.find { |r| r[:date] == target_date.iso8601 }
        expect(first_reservation).to include(
          date: target_date.iso8601,
          start_time: '10:00',
          end_time: '11:00',
          customer_name: '山田 花子'
        )
        
        # 2件目の予約を確認
        second_date = target_date + 4.days
        second_reservation = reservations.find { |r| r[:date] == second_date.iso8601 }
        expect(second_reservation).to include(
          date: second_date.iso8601,
          start_time: '14:00',
          end_time: '15:00',
          customer_name: '佐藤 次郎'
        )
      end

      it 'キャンセル済みの予約は含まれない' do
        setup_specific_date_working_hours(target_date + 9.days)
        
        create(:reservation,
          stylist:,
          customer:,
          start_at: (target_date + 9.days).to_time.change(hour: 10),
          end_at: (target_date + 9.days).to_time.change(hour: 11),
          status: :canceled)
        
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations = assigns(:existing_reservations)
        expect(reservations.size).to eq(2) # キャンセル済みは含まれない
        expect(reservations.none? { |r| r[:date] == (target_date + 9.days).iso8601 }).to be true
      end
    end

    context '月の設定状態の確認' do
      it '未設定の月はfalseを返す' do
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        expect(assigns(:month_already_configured)).to be false
      end

      it '設定済みの月はtrueを返す' do
        # 営業時間を設定
        create(:working_hour,
          stylist:,
          target_date: target_date,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))
        
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        expect(assigns(:month_already_configured)).to be true
      end
    end
  end

  describe 'private methods' do
    # fetch_month_reservations メソッドのテスト
    context '#fetch_month_reservations' do
      it '指定月の予約のみを取得する' do
        # 対象月の15日に営業時間を設定
        date_15 = target_date + 14.days
        setup_specific_date_working_hours(date_15)
        
        # 前月の最終日に営業時間を設定
        prev_month_date = target_date.prev_month.end_of_month
        setup_specific_date_working_hours(prev_month_date)
        
        # 翌月の1日に営業時間を設定
        next_month_date = target_date.next_month
        setup_specific_date_working_hours(next_month_date)
        
        # 対象月の予約
        create(:reservation,
          stylist:,
          customer:,
          start_at: date_15.to_time.change(hour: 10),
          end_at: date_15.to_time.change(hour: 11),
          status: :before_visit)
        
        # 前月の予約（含まれない）
        create(:reservation,
          stylist:,
          customer:,
          start_at: prev_month_date.to_time.change(hour: 10),
          end_at: prev_month_date.to_time.change(hour: 11),
          status: :before_visit)
        
        # 翌月の予約（含まれない）
        create(:reservation,
          stylist:,
          customer:,
          start_at: next_month_date.to_time.change(hour: 10),
          end_at: next_month_date.to_time.change(hour: 11),
          status: :before_visit)
        
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations = assigns(:existing_reservations)
        expect(reservations.size).to eq(1)
        expect(reservations.first[:date]).to eq(date_15.iso8601)
      end

      it '他のスタイリストの予約は含まれない' do
        other_stylist = create(:user, role: :stylist)
        
        # 他のスタイリストにもデフォルト設定を追加
        (0..7).each do |wday|
          create(:working_hour,
            stylist: other_stylist,
            day_of_week: wday,
            target_date: nil,
            start_time: Time.zone.parse('09:00'),
            end_time: Time.zone.parse('18:00'))
        end
        
        # 他のスタイリストのデフォルト予約上限も設定
        create(:reservation_limit,
          stylist: other_stylist,
          target_date: nil,
          time_slot: nil,
          max_reservations: 2)
        
        # 両スタイリストの特定日の営業時間を設定
        setup_specific_date_working_hours(target_date)
        
        create(:working_hour,
          stylist: other_stylist,
          target_date: target_date + 1.day,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))
        
        create(:reservation_limit,
          stylist: other_stylist,
          target_date: target_date + 1.day,
          time_slot: nil,
          max_reservations: 2)
        
        # 他のスタイリストの時間スロット予約上限も設定
        (18...36).each do |slot|  # 09:00-18:00の時間スロット
          create(:reservation_limit,
            stylist: other_stylist,
            target_date: target_date + 1.day,
            time_slot: slot,
            max_reservations: 2)
        end
        
        # 自分の予約
        create(:reservation,
          stylist:,
          customer:,
          start_at: target_date.to_time.change(hour: 10),
          end_at: target_date.to_time.change(hour: 11),
          status: :before_visit)
        
        # 他のスタイリストの予約
        create(:reservation,
          stylist: other_stylist,
          customer:,
          start_at: (target_date + 1.day).to_time.change(hour: 10),
          end_at: (target_date + 1.day).to_time.change(hour: 11),
          status: :before_visit)
        
        get show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations = assigns(:existing_reservations)
        expect(reservations.size).to eq(1)
        expect(reservations.first[:date]).to eq(target_date.iso8601)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength