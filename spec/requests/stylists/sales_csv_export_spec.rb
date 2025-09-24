# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe 'Stylists::Sales CSV Export' do
  let(:weekend_days) { [0, 6] }
  let(:stylist) { create(:user, :stylist) }
  let(:customer1) { create(:customer, family_name: '山田', given_name: '太郎') }
  let(:customer2) { create(:customer, family_name: '佐藤', given_name: '花子') }
  let(:menu) { create(:menu, stylist: stylist, name: 'カット', price: 3000, category: ['カット']) }
  let(:product) { create(:product, user: stylist, name: 'シャンプー', default_price: 2000) }

  let(:current_year) { Date.current.year }
  let(:current_month) { Date.current.month }

  def setup_working_environment(date)
    unless WorkingHour.exists?(stylist: stylist, target_date: date)
      create(:working_hour,
        stylist: stylist,
        target_date: date,
        start_time: '09:00',
        end_time: '19:00')
    end

    # メニューが60分なので、10:00-11:00の全スロット(20, 21)に予約制限を設定
    [20, 21].each do |slot|
      next if ReservationLimit.exists?(stylist: stylist, target_date: date, time_slot: slot)

      create(:reservation_limit,
        stylist: stylist,
        target_date: date,
        time_slot: slot,
        max_reservations: 1)
    end
  end

  def create_accounting_with_payment(customer, menu, payment_method, day_offset = 0)
    date = Date.current.beginning_of_month + day_offset.days
    date += 1.day while weekend_days.include?(date.wday)

    setup_working_environment(date)

    reservation = create(:reservation,
      stylist: stylist,
      customer: customer,
      start_at: date + 10.hours,
      menus: [menu])

    accounting = create(:accounting,
      reservation: reservation,
      total_amount: menu.price,
      status: :completed)

    create(:accounting_payment,
      accounting: accounting,
      payment_method: payment_method,
      amount: menu.price)

    accounting
  end

  before do
    sign_in stylist
    # 異なる日付に予約を作成
    create_accounting_with_payment(customer1, menu, 'cash', 0) # 月初の平日
    create_accounting_with_payment(customer2, menu, 'credit_card', 1) # 翌日
  end

  describe 'POST /stylists/sales/export' do
    context '標準形式' do
      it 'CSVファイルを正しくダウンロードできる' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'standard'
        }

        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Type']).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include(
          "sales_standard_#{current_year}_#{current_month}.csv"
        )
      end

      it '正しいヘッダーとデータが含まれている' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'standard'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        # ヘッダーの確認
        expect(csv.headers).to eq(%w[日付 予約ID 顧客名 技術売上 商品売上 合計金額 メニュー カテゴリー])

        # データの確認
        expect(csv.size).to eq(2)
        expect(csv[0]['顧客名']).to eq('山田 太郎')
        expect(csv[0]['技術売上']).to eq('3000')
        expect(csv[1]['顧客名']).to eq('佐藤 花子')
      end
    end

    context 'マネーフォワード形式' do
      it 'CSVファイルを正しくダウンロードできる' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'moneyforward'
        }

        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Type']).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include(
          "sales_moneyforward_#{current_year}_#{current_month}.csv"
        )
      end

      it '支払い方法に応じた借方勘定科目が設定される' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'moneyforward'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        # 現金の行
        cash_row = csv.find { |row| row['摘要'] == '山田 太郎' }
        expect(cash_row['借方勘定科目']).to eq('現金')

        # クレジットカードの行
        credit_row = csv.find { |row| row['摘要'] == '佐藤 花子' }
        expect(credit_row['借方勘定科目']).to eq('売掛金')
      end

      it '貸方勘定科目が売上高に統一されている' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'moneyforward'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        csv.each do |row|
          expect(row['貸方勘定科目']).to eq('売上高')
        end
      end

      it '備考欄に予約IDが含まれる' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'moneyforward'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')

        expect(csv_content).to include('予約ID:')
      end
    end

    context 'freee形式' do
      it 'CSVファイルを正しくダウンロードできる' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'freee'
        }

        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Type']).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include("sales_freee_#{current_year}_#{current_month}.csv")
      end

      it '正しいヘッダーが含まれている' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'freee'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        # ヘッダーの確認（決済状況は削除、取引日→発生日）
        expect(csv.headers).to eq(%w[発生日 収支区分 取引先 勘定科目 税区分 金額 備考])
      end

      it '勘定科目が「売上高」に統一されている' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'freee'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        csv.each do |row|
          expect(row['勘定科目']).to eq('売上高')
        end
      end

      it '備考欄に予約IDが含まれる' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'freee'
        }

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')

        expect(csv_content).to include('予約ID:')
      end
    end

    context 'データがない月' do
      it 'ヘッダーのみのCSVファイルがダウンロードできる' do
        next_month = Date.current.next_month

        post export_stylists_sales_path, params: {
          year: next_month.year,
          month: next_month.month,
          format_type: 'standard'
        }

        expect(response).to have_http_status(:success)

        csv_content = response.body.force_encoding('SJIS').encode('UTF-8')
        csv = CSV.parse(csv_content, headers: true)

        expect(csv.headers).to eq(%w[日付 予約ID 顧客名 技術売上 商品売上 合計金額 メニュー カテゴリー])
        expect(csv.size).to eq(0)
      end
    end
  end

  describe '権限チェック' do
    context 'ログインしていない場合' do
      before { sign_out stylist }

      it 'CSVエクスポートができない' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'standard'
        }

        expect(response).to redirect_to('/login')
      end
    end

    context '顧客としてログインした場合' do
      let(:customer) { create(:user, :customer) }

      before do
        sign_out stylist
        sign_in customer
      end

      it 'CSVエクスポートができない' do
        post export_stylists_sales_path, params: {
          year: current_year,
          month: current_month,
          format_type: 'standard'
        }

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
