# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Shift settings reservation data', type: :system, js: true do
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
      given_name: '花子',
      family_name_kana: 'ヤマダ',
      given_name_kana: 'ハナコ')
  end

  let(:current_year) { Time.zone.today.year }
  let(:current_month) { Time.zone.today.month }
  let(:target_date) { Date.new(current_year, current_month, 1) }

  before do
    sign_in stylist
    # デフォルトのシフト設定を作成
    setup_default_shift_settings
  end

  def setup_default_shift_settings
    # デフォルトの営業時間を設定
    (1..5).each do |wday|
      create(:working_hour,
        stylist:,
        day_of_week: wday,
        target_date: nil,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))
    end
    
    # 土日
    [0, 6].each do |wday|
      create(:working_hour,
        stylist:,
        day_of_week: wday,
        target_date: nil,
        start_time: Time.zone.parse('10:00'),
        end_time: Time.zone.parse('17:00'))
    end
    
    # 祝日
    create(:working_hour,
      stylist:,
      day_of_week: 7,
      target_date: nil,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('17:00'))
    
    # デフォルトの予約上限
    create(:reservation_limit,
      stylist:,
      target_date: nil,
      time_slot: nil,
      max_reservations: 2)
  end

  def setup_specific_date_shift(date, start_time: '09:00', end_time: '18:00')
    # 特定日の営業時間を設定
    create(:working_hour,
      stylist:,
      target_date: date,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
    
    # 休業日でないことを明示
    create(:holiday,
      stylist:,
      target_date: date,
      is_holiday: false)
    
    # その日の各時間スロットの予約上限も設定
    create(:reservation_limit,
      stylist:,
      target_date: date,
      time_slot: nil,
      max_reservations: 2)
    
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

  describe '予約データの取得と表示' do
    context '予約がない月の場合' do
      it 'ページが正常に表示される' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        expect(page).to have_content("#{current_year}年#{current_month}月の受付設定")
        expect(page).to have_button('一括設定')
        
        # JavaScriptコンソールでデータを確認
        reservations_data = page.evaluate_script('document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue')
        expect(JSON.parse(reservations_data)).to eq([])
      end
    end

    context '予約がある月の場合' do
      before do
        # 特定の日付に営業時間を設定
        setup_specific_date_shift(target_date)
        setup_specific_date_shift(target_date + 4.days)
        
        # 予約を作成
        create(:reservation,
          stylist:,
          customer:,
          start_at: target_date.to_time.change(hour: 10),
          end_at: target_date.to_time.change(hour: 11),
          status: :before_visit)
        
        create(:reservation,
          stylist:,
          customer: create(:user, role: :customer, family_name: '佐藤', given_name: '次郎'),
          start_at: (target_date + 4.days).to_time.change(hour: 14),
          end_at: (target_date + 4.days).to_time.change(hour: 15),
          status: :paid)
      end

      it '予約データが正しくJavaScriptに渡される' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        # JavaScriptコンソールでデータを確認
        reservations_data = page.evaluate_script('document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue')
        reservations = JSON.parse(reservations_data)
        
        expect(reservations.size).to eq(2)
        
        # 1件目の予約
        first_reservation = reservations.find { |r| r['date'] == target_date.iso8601 }
        expect(first_reservation).to include(
          'date' => target_date.iso8601,
          'start_time' => '10:00',
          'end_time' => '11:00',
          'customer_name' => '山田 花子'
        )
        
        # 2件目の予約
        second_date = target_date + 4.days
        second_reservation = reservations.find { |r| r['date'] == second_date.iso8601 }
        expect(second_reservation).to include(
          'date' => second_date.iso8601,
          'start_time' => '14:00',
          'end_time' => '15:00',
          'customer_name' => '佐藤 次郎'
        )
      end

      it 'キャンセル済みの予約は含まれない' do
        setup_specific_date_shift(target_date + 9.days)
        
        canceled_customer = create(:user, role: :customer, family_name: '鈴木', given_name: '太郎')
        create(:reservation,
          stylist:,
          customer: canceled_customer,
          start_at: (target_date + 9.days).to_time.change(hour: 10),
          end_at: (target_date + 9.days).to_time.change(hour: 11),
          status: :canceled)
        
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations_data = page.evaluate_script('document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue')
        reservations = JSON.parse(reservations_data)
        
        # キャンセル済みの予約が含まれていないことを確認
        expect(reservations.size).to eq(2)
        expect(reservations.none? { |r| r['customer_name'].include?('鈴木') }).to be true
      end
    end

    context '月の設定状態の確認' do
      it '未設定の月の場合' do
        visit stylists_shift_settings_path
        
        # 未設定と表示されることを確認
        within('.card', text: "#{current_month}月") do
          expect(page).to have_content('未設定')
        end
      end

      it '設定済みの月の場合' do
        # 営業時間を設定
        create(:working_hour,
          stylist:,
          target_date: target_date,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))
        
        visit stylists_shift_settings_path
        
        # 設定済みと表示されることを確認
        within('.card', text: "#{current_month}月") do
          expect(page).to have_content('設定済み')
        end
      end
    end

    context '指定月の予約のみを取得' do
      before do
        # 対象月の15日に営業時間を設定
        date_15 = target_date + 14.days
        setup_specific_date_shift(date_15)
        
        # 前月の最終日に営業時間を設定
        prev_month_date = target_date.prev_month.end_of_month
        setup_specific_date_shift(prev_month_date)
        
        # 翌月の1日に営業時間を設定
        next_month_date = target_date.next_month
        setup_specific_date_shift(next_month_date)
        
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
      end

      it '指定月の予約のみがデータに含まれる' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations_data = page.evaluate_script('document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue')
        reservations = JSON.parse(reservations_data)
        
        expect(reservations.size).to eq(1)
        expect(reservations.first['date']).to eq((target_date + 14.days).iso8601)
      end
    end

    context '他のスタイリストの予約' do
      before do
        other_stylist = create(:user, role: :stylist, family_name: '他の', given_name: 'スタイリスト')
        
        # 他のスタイリストのデフォルト設定
        (0..7).each do |wday|
          create(:working_hour,
            stylist: other_stylist,
            day_of_week: wday,
            target_date: nil,
            start_time: Time.zone.parse('09:00'),
            end_time: Time.zone.parse('18:00'))
        end
        
        create(:reservation_limit,
          stylist: other_stylist,
          target_date: nil,
          time_slot: nil,
          max_reservations: 2)
        
        # 両スタイリストの特定日の営業時間を設定
        setup_specific_date_shift(target_date)
        
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
        
        (18...36).each do |slot|
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
        other_customer = create(:user, role: :customer, family_name: '他の', given_name: '顧客')
        create(:reservation,
          stylist: other_stylist,
          customer: other_customer,
          start_at: (target_date + 1.day).to_time.change(hour: 10),
          end_at: (target_date + 1.day).to_time.change(hour: 11),
          status: :before_visit)
      end

      it '他のスタイリストの予約は含まれない' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
        
        reservations_data = page.evaluate_script('document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue')
        reservations = JSON.parse(reservations_data)
        
        expect(reservations.size).to eq(1)
        expect(reservations.first['customer_name']).to eq('山田 花子')
        expect(reservations.none? { |r| r['customer_name'].include?('他の') }).to be true
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength