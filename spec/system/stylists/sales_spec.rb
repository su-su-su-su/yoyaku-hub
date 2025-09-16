# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Sales' do
  let(:stylist) { create(:user, :stylist) }
  let(:customer1) { create(:customer, family_name: '山田', given_name: '太郎') }
  let(:customer2) { create(:customer, family_name: '佐藤', given_name: '花子') }
  let(:cut_menu) { create(:menu, stylist: stylist, name: 'カット', price: 3000, duration: 60, category: ['カット']) }
  let(:color_menu) { create(:menu, stylist: stylist, name: 'カラー', price: 5000, duration: 90, category: ['カラー']) }
  let(:perm_menu) { create(:menu, stylist: stylist, name: 'パーマ', price: 7000, duration: 120, category: ['パーマ']) }
  let(:product1) { create(:product, user: stylist, name: 'シャンプー', default_price: 2000) }
  let(:product2) { create(:product, user: stylist, name: 'トリートメント', default_price: 3000) }

  let(:current_year) { Date.current.year }
  let(:current_month) { Date.current.month }
  let(:prev_month_date) { Date.current.prev_month }
  let(:current_date) { Date.current }

  def to_slot_index(time_str)
    h, m = time_str.split(':').map(&:to_i)
    (h * 2) + (m >= 30 ? 1 : 0)
  end

  def create_reservation_with_accounting(date, customer, menus, payment_method: 'cash', products: [], time: '10:00')
    # 営業時間を設定（既存の場合はスキップ）
    unless WorkingHour.exists?(stylist_id: stylist.id, target_date: date)
      create(:working_hour,
        stylist: stylist,
        target_date: date,
        start_time: '09:00',
        end_time: '19:00')
    end

    # 予約上限を設定（既存の場合はスキップ）
    ['10:00', '10:30', '11:00', '11:30', '12:00', '14:00', '14:30', '15:00'].each do |slot_time|
      slot_index = to_slot_index(slot_time)
      next if ReservationLimit.exists?(stylist_id: stylist.id, target_date: date, time_slot: slot_index)

      create(:reservation_limit,
        stylist: stylist,
        target_date: date,
        time_slot: slot_index,
        max_reservations: 1)
    end

    # 予約を作成
    reservation = create(:reservation,
      stylist: stylist,
      customer: customer,
      start_at: Time.zone.parse("#{date} #{time}"),
      menus: menus)

    # 会計を作成
    total_amount = menus.sum(&:price) + products.sum { |p| p[:quantity] * p[:product].default_price }
    accounting = create(:accounting,
      reservation: reservation,
      total_amount: total_amount,
      status: :completed)

    # 支払い情報を作成
    create(:accounting_payment,
      accounting: accounting,
      payment_method: payment_method,
      amount: total_amount)

    # 商品情報を作成
    products.each do |product_data|
      create(:accounting_product,
        accounting: accounting,
        product: product_data[:product],
        quantity: product_data[:quantity],
        actual_price: product_data[:product].default_price)
    end

    accounting
  end

  before do
    sign_in stylist
  end

  describe '売り上げ一覧画面' do
    context '売り上げデータがある場合' do
      before do
        # 今月の売上データを作成
        create_reservation_with_accounting(
          current_date,
          customer1,
          [cut_menu, color_menu],
          payment_method: 'cash',
          products: [{ product: product1, quantity: 1 }],
          time: '10:00'
        )

        create_reservation_with_accounting(
          current_date,
          customer2,
          [perm_menu],
          payment_method: 'credit_card',
          time: '14:00'
        )

        # 前月の売上データを作成
        create_reservation_with_accounting(
          prev_month_date,
          customer1,
          [cut_menu],
          payment_method: 'cash'
        )

        visit stylists_sales_path
      end

      it '売り上げ管理ページが表示される' do
        expect(page).to have_content('売り上げ管理')
        # ドロップダウンで現在の年月が選択されていることを確認
        selects = page.all('select')
        expect(selects[0].value).to eq(current_year.to_s)
        expect(selects[1].value).to eq(current_month.to_s)
      end

      it '月間サマリーが表示される' do
        expect(page).to have_content('総売上')
        expect(page).to have_content('¥17,000') # 3000 + 5000 + 2000 + 7000

        expect(page).to have_content('技術売上')
        expect(page).to have_content('¥15,000') # 3000 + 5000 + 7000

        expect(page).to have_content('商品売上')
        expect(page).to have_content('¥2,000') # 2000

        expect(page).to have_content('予約数')
        expect(page).to have_content('2件')

        expect(page).to have_content('技術平均単価')
        expect(page).to have_content('¥7,500') # 15000 / 2

        expect(page).to have_content('日平均売上')
      end

      it 'カテゴリー別売上が表示される' do
        expect(page).to have_content('カテゴリー別売上')
        expect(page).to have_content('カット')
        expect(page).to have_content('カラー')
        expect(page).to have_content('パーマ')
      end

      it '前月・次月へのナビゲーションができる' do
        click_on '前月へ'

        # ページ遷移を待つ - 前月の年月がURLに含まれることを確認
        expect(page).to have_current_path(stylists_sales_path(year: prev_month_date.year, month: prev_month_date.month))

        # ページ遷移後に要素を取得
        within '.flex.items-center.gap-2[data-controller="sales-date-picker"]' do
          selects = all('select')
          expect(selects[0].value).to eq(prev_month_date.year.to_s)
          expect(selects[1].value).to eq(prev_month_date.month.to_s)
        end
        expect(page).to have_content('¥3,000') # 前月の総売上

        click_on '次月へ'

        # ページ遷移を待つ - 現在の年月がURLに含まれることを確認
        expect(page).to have_current_path(stylists_sales_path(year: current_year, month: current_month))

        # ページ遷移後に要素を取得
        within '.flex.items-center.gap-2[data-controller="sales-date-picker"]' do
          selects = all('select')
          expect(selects[0].value).to eq(current_year.to_s)
          expect(selects[1].value).to eq(current_month.to_s)
        end
      end
    end

    context '売り上げデータがない場合' do
      before do
        visit stylists_sales_path
      end

      it '0円が表示される' do
        expect(page).to have_content('総売上')
        expect(page).to have_content('¥0')

        expect(page).to have_content('技術売上')
        expect(page).to have_content('¥0')

        expect(page).to have_content('商品売上')
        expect(page).to have_content('¥0')

        expect(page).to have_content('予約数')
        expect(page).to have_content('0件')

        expect(page).to have_content('技術平均単価')
        expect(page).to have_content('¥0')

        expect(page).to have_content('日平均売上')
        expect(page).to have_content('¥0')
      end

      it 'カテゴリー別売上が表示されない' do
        expect(page).to have_no_content('カテゴリー別売上')
      end
    end

    context '年月を指定してアクセスした場合' do
      it '指定した年月の売り上げが表示される' do
        visit stylists_sales_path(year: 2024, month: 3)
        selects = page.all('select')
        expect(selects[0].value).to eq('2024')
        expect(selects[1].value).to eq('3')
      end
    end

    context '年月選択ドロップダウン' do
      before do
        # 2024年5月のデータを作成
        may_date = Date.new(2024, 5, 15)
        create_reservation_with_accounting(
          may_date,
          customer1,
          [cut_menu],
          payment_method: 'cash'
        )

        visit stylists_sales_path
      end

      it '年と月のドロップダウンが表示される' do
        expect(page.all('select').count).to eq(2)
      end

      it '現在の年月が選択されている' do
        year_select = page.all('select')[0]
        month_select = page.all('select')[1]

        expect(year_select.value).to eq current_year.to_s
        expect(month_select.value).to eq current_month.to_s
      end

      it '年の選択肢が2020年から来年まで表示される' do
        year_select = page.all('select')[0]
        options = year_select.all('option').map(&:text)

        expect(options.first).to eq '2020年'
        expect(options.last).to eq "#{Date.current.year + 1}年"
      end

      it '月の選択肢が1月から12月まで表示される' do
        month_select = page.all('select')[1]
        options = month_select.all('option').map(&:text)

        expect(options).to eq((1..12).map { |m| "#{m}月" })
      end

      it 'ドロップダウンで年月を変更できる', :js do
        # 2024年5月を選択
        page.all('select')[0].select('2024年')
        page.all('select')[1].select('5月')

        # デバウンスを待つ
        sleep 0.6

        # ページが遷移することを確認（URLパラメータの順番は問わない）
        expect(page).to have_current_path(%r{/stylists/sales\?.*year=2024.*month=5|/stylists/sales\?.*month=5.*year=2024})
        expect(page.all('select')[0].value).to eq('2024')
        expect(page.all('select')[1].value).to eq('5')

        # 2024年5月の売上が表示される
        expect(page).to have_content('¥3,000')
      end
    end
  end

  describe 'ダッシュボードからのアクセス' do
    before do
      visit stylists_dashboard_path
    end

    it '売り上げ管理へのリンクが表示される' do
      expect(page).to have_link('売り上げ管理')
    end

    it '売り上げ管理ページへ遷移できる' do
      click_on '売り上げ管理'
      expect(page).to have_current_path(stylists_sales_path)
      expect(page).to have_content('売り上げ管理')
    end
  end

  describe 'ナビゲーションメニューからのアクセス' do
    before do
      visit stylists_dashboard_path
    end

    it 'ナビゲーションメニューに売り上げ管理リンクが表示される' do
      within('.navbar') do
        find('.btn-ghost.btn-circle').click
        expect(page).to have_link('売り上げ管理')
      end
    end

    it 'ナビゲーションメニューから売り上げ管理ページへ遷移できる' do
      within('.navbar') do
        find('.btn-ghost.btn-circle').click
        click_on '売り上げ管理'
      end
      expect(page).to have_current_path(stylists_sales_path)
    end
  end

  describe '権限チェック' do
    context '顧客としてログインした場合' do
      let(:customer) { create(:user, :customer) }

      before do
        sign_in customer
      end

      it '売り上げ管理ページにアクセスできない' do
        visit stylists_sales_path
        expect(page).to have_current_path(root_path)
      end
    end

    context 'ログインしていない場合' do
      before do
        sign_out stylist
      end

      it '売り上げ管理ページにアクセスできない' do
        visit stylists_sales_path
        expect(page).to have_current_path('/login')
      end
    end
  end
end
