# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe 'Shift settings with reservation conflicts', :js do
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

  describe '予約が入っている月の再設定' do
    context 'when trying to set a day with reservations as a holiday' do
      before do
        # 1日の営業時間を設定
        setup_specific_date_shift(target_date)

        # 1日の10:00-11:00に予約を作成（バリデーションをスキップ）
        reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date} 10:00"),
          end_at: Time.zone.parse("#{target_date} 11:00"),
          status: :before_visit)
        reservation.save(validate: false)

        # 月の設定画面を直接開く（初回設定を省略）
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
      end

      it '休業日に設定しようとするとアラートが表示される' do
        # 1日を休業日に設定
        within("td[class*='wday-'][class*='border']", match: :first) do
          check '休'
        end

        # alertをacceptする設定（アラートは自動的に閉じられる）
        accept_alert do
          click_on '一括設定'
        end

        # ページがリロードされていないことを確認（設定が中止された）
        expect(page).to have_current_path(show_stylists_shift_settings_path(year: current_year, month: current_month))
      end

      it 'アラートメッセージに正しい予約情報が表示される' do
        within("td[class*='wday-'][class*='border']", match: :first) do
          check '休'
        end

        message = accept_alert do
          click_on '一括設定'
        end

        expect(message).to include('以下の予約があるため、設定できません')
        expect(message).to include('休業日に設定しようとしている日に予約があります')
        expect(message).to include("#{current_month}月1日")
        expect(message).to include('10:00〜11:00')
        expect(message).to include('山田 花子様')
        expect(message).to include('予約の変更または設定の見直しをお願いします')
      end
    end

    context 'when trying to set business hours that exclude existing reservations' do
      before do
        # 5日の営業時間を設定
        date5 = target_date + 4.days
        setup_specific_date_shift(date5, start_time: '09:00', end_time: '18:00')

        # 5日の14:00-15:00に予約を作成（バリデーションをスキップ）
        reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{date5} 14:00"),
          end_at: Time.zone.parse("#{date5} 15:00"),
          status: :before_visit)
        reservation.save(validate: false)

        # 月の設定画面を直接開く（初回設定を省略）
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
      end

      it '営業時間を短縮するとアラートが表示される' do
        # 5日の営業時間を10:00-13:00に変更（14:00の予約が時間外になる）
        within all("td[class*='wday-'][class*='border']")[4] do
          find("select[data-holiday-toggle-target='startTime']").select('10:00')
          find("select[data-holiday-toggle-target='endTime']").select('13:00')
        end

        accept_alert do
          click_on '一括設定'
        end

        expect(page).to have_current_path(show_stylists_shift_settings_path(year: current_year, month: current_month))
      end

      it 'アラートメッセージに営業時間外の情報が表示される' do
        within all("td[class*='wday-'][class*='border']")[4] do
          find("select[data-holiday-toggle-target='startTime']").select('10:00')
          find("select[data-holiday-toggle-target='endTime']").select('13:00')
        end

        message = accept_alert do
          click_on '一括設定'
        end

        expect(message).to include('営業時間外になってしまう予約があります')
        expect(message).to include("#{current_month}月5日")
        expect(message).to include('予約：14:00〜15:00')
        expect(message).to include('山田 花子様')
        expect(message).to include('新しい営業時間：10:00〜13:00')
      end
    end

    context 'when there are multiple conflicts' do
      before do
        # 複数の日に営業時間を設定
        setup_specific_date_shift(target_date)
        setup_specific_date_shift(target_date + 2.days)

        # 複数の予約を作成（バリデーションをスキップ）
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
          start_at: Time.zone.parse("#{target_date + 2.days} 14:00"),
          end_at: Time.zone.parse("#{target_date + 2.days} 15:00"),
          status: :paid)
        reservation2.save(validate: false)

        customer3 = create(:user, role: :customer, family_name: '鈴木', given_name: '三郎')
        reservation3 = build(:reservation,
          stylist:,
          customer: customer3,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date} 16:00"),
          end_at: Time.zone.parse("#{target_date} 17:00"),
          status: :before_visit)
        reservation3.save(validate: false)

        # 月の設定画面を直接開く（初回設定を省略）
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
      end

      it '複数の競合が日付順・時間順にソートされて表示される' do
        # 1日を休業日、3日を短縮営業に設定
        within all("td[class*='wday-'][class*='border']")[0] do
          check '休'
        end

        within all("td[class*='wday-'][class*='border']")[2] do
          find("select[data-holiday-toggle-target='startTime']").select('10:00')
          find("select[data-holiday-toggle-target='endTime']").select('13:00')
        end

        message = accept_alert do
          click_on '一括設定'
        end

        # メッセージの順序を確認（1日の早い時間→1日の遅い時間→3日）
        lines = message.split("\n")

        # 1日の予約が時間順に表示されることを確認
        expect(lines.find { |l| l.include?('1日') && l.include?('10:00') }).to be_truthy
        expect(lines.find { |l| l.include?('1日') && l.include?('16:00') }).to be_truthy

        # 1日の10:00が16:00より先に表示されることを確認
        idx10 = lines.index { |l| l.include?('1日') && l.include?('10:00') }
        idx16 = lines.index { |l| l.include?('1日') && l.include?('16:00') }
        expect(idx10).to be < idx16 if idx10 && idx16

        # 3日の予約も表示されることを確認
        expect(message).to include('3日')
        expect(message).to include('佐藤 次郎様')
      end
    end

    context 'when setting days without reservations' do
      before do
        # 10日には予約を作らない
        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
      end

      it '予約がない日を休業日に設定してもアラートが表示されない' do
        # 一部の日を営業日として設定し、10日を休業日に設定
        # 1日を営業日として設定
        within all("td[class*='wday-'][class*='border']")[0] do
          uncheck '休' if has_checked_field?('休')
          select '09:00', from: find("select[data-holiday-toggle-target='startTime']")[:name]
          select '18:00', from: find("select[data-holiday-toggle-target='endTime']")[:name]
        end

        # 10日を休業日に設定
        within all("td[class*='wday-'][class*='border']")[9] do
          check '休'
        end

        # アラートが表示されないことを確認して、フォームが送信される
        click_on '一括設定'

        # フォーム送信処理が時間がかかる場合があるため、長めに待つ
        # リダイレクト後、設定ページに戻ることを確認
        expect(page).to have_current_path(stylists_shift_settings_path, wait: 10)
      end
    end

    context 'when there are canceled or visited reservations' do
      before do
        # 2日と3日の営業時間を設定
        setup_specific_date_shift(target_date + 1.day)
        setup_specific_date_shift(target_date + 2.days)

        # キャンセル済みの予約（バリデーションをスキップ）
        canceled_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date + 1.day} 10:00"),
          end_at: Time.zone.parse("#{target_date + 1.day} 11:00"),
          status: :canceled)
        canceled_reservation.save(validate: false)

        # 来店済み（no_show）の予約（バリデーションをスキップ）
        no_show_reservation = build(:reservation,
          stylist:,
          customer:,
          menu_ids: [menu.id],
          start_at: Time.zone.parse("#{target_date + 2.days} 10:00"),
          end_at: Time.zone.parse("#{target_date + 2.days} 11:00"),
          status: :no_show)
        no_show_reservation.save(validate: false)

        visit show_stylists_shift_settings_path(year: current_year, month: current_month)
      end

      it 'キャンセル済みの予約はアラート対象にならない' do
        # 一部の日を営業日として設定
        # 1日を営業日として設定
        within all("td[class*='wday-'][class*='border']")[0] do
          uncheck '休' if has_checked_field?('休')
          select '09:00', from: find("select[data-holiday-toggle-target='startTime']")[:name]
          select '18:00', from: find("select[data-holiday-toggle-target='endTime']")[:name]
        end

        # 2日と3日を休業日に設定
        within all("td[class*='wday-'][class*='border']")[1] do
          check '休'
        end

        within all("td[class*='wday-'][class*='border']")[2] do
          check '休'
        end

        # アラートが表示されないことを確認して、フォームが送信される
        click_on '一括設定'

        # フォーム送信処理が時間がかかる場合があるため、長めに待つ
        # リダイレクト後、設定ページに戻ることを確認
        expect(page).to have_current_path(stylists_shift_settings_path, wait: 10)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
# rubocop:enable RSpec/MultipleMemoizedHelpers
