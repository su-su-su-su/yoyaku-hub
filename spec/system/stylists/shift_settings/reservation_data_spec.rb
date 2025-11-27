# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe 'Shift settings reservation data', :js do
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

  let(:menu) { create(:menu, stylist:, name: 'カット', price: 3000, duration: 60) }

  let(:current_year) { Time.zone.today.year }
  let(:current_month) { Time.zone.today.month }
  let(:target_date) { Date.new(current_year, current_month, 1) }

  before do
    sign_in stylist
    # デフォルトのシフト設定を作成
    setup_default_shift_settings
  end

  def setup_default_shift_settings
    setup_weekday_hours
    setup_weekend_hours
    setup_holiday_hours
    setup_default_reservation_limit
  end

  def setup_weekday_hours
    (1..5).each do |wday|
      create(:working_hour,
        stylist:,
        day_of_week: wday,
        target_date: nil,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('18:00'))
    end
  end

  def setup_weekend_hours
    [0, 6].each do |wday|
      create(:working_hour,
        stylist:,
        day_of_week: wday,
        target_date: nil,
        start_time: Time.zone.parse('10:00'),
        end_time: Time.zone.parse('17:00'))
    end
  end

  def setup_holiday_hours
    create(:working_hour,
      stylist:,
      day_of_week: 7,
      target_date: nil,
      start_time: Time.zone.parse('10:00'),
      end_time: Time.zone.parse('17:00'))
  end

  def setup_default_reservation_limit
    create(:reservation_limit,
      stylist:,
      target_date: nil,
      time_slot: nil,
      max_reservations: 2)
  end

  def setup_specific_date_shift(date, start_time: '09:00', end_time: '18:00')
    setup_date_working_hours(date, start_time, end_time)
    mark_as_working_day(date)
    setup_date_reservation_limits(date, start_time, end_time)
  end

  def setup_date_working_hours(date, start_time, end_time)
    create(:working_hour,
      stylist:,
      target_date: date,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
  end

  def mark_as_working_day(date)
    create(:holiday,
      stylist:,
      target_date: date,
      is_holiday: false)
  end

  def setup_date_reservation_limits(date, start_time, end_time)
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
    context 'when there are no reservations in the month' do
      it 'ページが正常に表示される' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)

        expect(page).to have_content("#{current_year}年#{current_month}月の受付設定")
        expect(page).to have_button('一括設定')

        # JavaScriptコンソールでデータを確認
        reservations_data = page.evaluate_script(
          'document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue'
        )
        expect(JSON.parse(reservations_data)).to eq([])
      end
    end

    context 'when there are reservations in the month' do
      before do
        # 特定の日付に営業時間を設定
        setup_specific_date_shift(target_date)
        setup_specific_date_shift(target_date + 4.days)

        # 予約を作成（バリデーションをスキップ）
        reservation1 = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date} 10:00"),
          end_at: Time.zone.parse("#{target_date} 11:00"),
          status: :before_visit)
        reservation1.save(validate: false)

        customer2 = create(:user, role: :customer, family_name: '佐藤', given_name: '次郎')
        reservation2 = build(:reservation,
          stylist:,
          customer: customer2,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date + 4.days} 14:00"),
          end_at: Time.zone.parse("#{target_date + 4.days} 15:00"),
          status: :paid)
        reservation2.save(validate: false)
      end

      it '予約データが正しくJavaScriptに渡される' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)

        reservations_data = page.evaluate_script(
          'document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue'
        )
        reservations = JSON.parse(reservations_data)

        expect(reservations.size).to eq(2)
        verify_first_reservation(reservations)
        verify_second_reservation(reservations)
      end

      def verify_first_reservation(reservations)
        first_reservation = reservations.find { |r| r['date'] == target_date.iso8601 }
        expect(first_reservation).to include(
          'date' => target_date.iso8601,
          'start_time' => '10:00',
          'end_time' => '11:00',
          'customer_name' => '山田 花子'
        )
      end

      def verify_second_reservation(reservations)
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
        canceled_reservation = build(:reservation,
          stylist:,
          customer: canceled_customer,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date + 9.days} 10:00"),
          end_at: Time.zone.parse("#{target_date + 9.days} 11:00"),
          status: :canceled)
        canceled_reservation.save(validate: false)

        visit show_stylists_shift_settings_path(year: current_year, month: current_month)

        reservations_data = page.evaluate_script(
          'document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue'
        )
        reservations = JSON.parse(reservations_data)

        # キャンセル済みの予約が含まれていないことを確認
        expect(reservations.size).to eq(2)
        expect(reservations.none? { |r| r['customer_name'].include?('鈴木') }).to be true
      end
    end

    context 'when checking monthly setting status' do
      it '未設定の月の場合' do
        visit stylists_shift_settings_path

        # 未設定と表示されることを確認
        month_link = find('a', text: /#{current_month}月/)
        expect(month_link).to have_content('未設定')
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
        month_link = find('a', text: /#{current_month}月/)
        expect(month_link).to have_content('設定済')
      end
    end

    context 'when fetching reservations only for the specified month' do
      before do
        # 対象月の15日に営業時間を設定
        date15 = target_date + 14.days
        setup_specific_date_shift(date15)

        # 前月の最終日に営業時間を設定
        prev_month_date = target_date.prev_month.end_of_month
        setup_specific_date_shift(prev_month_date)

        # 翌月の1日に営業時間を設定
        next_month_date = target_date.next_month
        setup_specific_date_shift(next_month_date)

        # 対象月の予約（バリデーションをスキップ）
        current_month_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{date15} 10:00"),
          end_at: Time.zone.parse("#{date15} 11:00"),
          status: :before_visit)
        current_month_reservation.save(validate: false)

        # 前月の予約（含まれない）（バリデーションをスキップ）
        prev_month_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{prev_month_date} 10:00"),
          end_at: Time.zone.parse("#{prev_month_date} 11:00"),
          status: :before_visit)
        prev_month_reservation.save(validate: false)

        # 翌月の予約（含まれない）（バリデーションをスキップ）
        next_month_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{next_month_date} 10:00"),
          end_at: Time.zone.parse("#{next_month_date} 11:00"),
          status: :before_visit)
        next_month_reservation.save(validate: false)
      end

      it '指定月の予約のみがデータに含まれる' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)

        reservations_data = page.evaluate_script(
          'document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue'
        )
        reservations = JSON.parse(reservations_data)

        expect(reservations.size).to eq(1)
        expect(reservations.first['date']).to eq((target_date + 14.days).iso8601)
      end
    end

    context 'when there are reservations for other stylists' do
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

        # 自分の予約（バリデーションをスキップ）
        my_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date} 10:00"),
          end_at: Time.zone.parse("#{target_date} 11:00"),
          status: :before_visit)
        my_reservation.save(validate: false)

        # 他のスタイリストの予約（バリデーションをスキップ）
        other_customer = create(:user, role: :customer, family_name: '他の', given_name: '顧客')
        other_menu = create(:menu, stylist: other_stylist, name: 'カット', price: 3000, duration: 60)
        other_reservation = build(:reservation,
          stylist: other_stylist,
          customer: other_customer,
          menu_ids: [other_menu.id],
          start_at: Time.zone.parse("#{target_date + 1.day} 10:00"),
          end_at: Time.zone.parse("#{target_date + 1.day} 11:00"),
          status: :before_visit)
        other_reservation.save(validate: false)
      end

      it '他のスタイリストの予約は含まれない' do
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)

        reservations_data = page.evaluate_script(
          'document.querySelector(".simple-calendar").dataset.shiftConfirmationExistingReservationsValue'
        )
        reservations = JSON.parse(reservations_data)

        expect(reservations.size).to eq(1)
        expect(reservations.first['customer_name']).to eq('山田 花子')
        expect(reservations.none? { |r| r['customer_name'].include?('他の') }).to be true
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable RSpec/MultipleMemoizedHelpers
