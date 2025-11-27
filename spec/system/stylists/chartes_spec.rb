# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists Chartes' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:stylist) do
    create(:user, role: :stylist,
      family_name: '美容師', given_name: '太郎',
      email: 'stylist@example.com', password: 'password', password_confirmation: 'password')
  end

  let(:customer) do
    create(:user, role: :customer,
      family_name: '山田', given_name: '太郎',
      family_name_kana: 'ヤマダ', given_name_kana: 'タロウ',
      date_of_birth: 30.years.ago.to_date)
  end

  let(:other_stylist) { create(:user, role: :stylist) }
  let(:menu) { create(:menu, stylist: stylist, name: 'カット') }
  let(:other_menu) { create(:menu, stylist: other_stylist) }

  let(:paid_reservation) do
    create(:reservation, customer: customer, stylist: stylist, status: :paid,
      menu_ids: [menu.id], start_date_str: 1.month.ago.to_date.to_s, start_time_str: '10:00')
  end

  def setup_working_hours(target_dates, stylists)
    target_dates.each do |target_date|
      stylists.each do |s|
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
  end

  before do
    setup_working_hours([1.month.ago.to_date, Date.current], [stylist, other_stylist])
    paid_reservation
    login_as_stylist
  end

  def login_as_stylist
    visit new_user_session_path
    fill_in 'user_email', with: stylist.email
    fill_in 'user_password', with: 'password'
    click_on 'ログイン'

    expect(page).to have_current_path(stylists_dashboard_path)
  end

  describe 'Carte index page' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when no cartes exist' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'displays empty state with create button' do
        visit stylists_customer_chartes_path(customer)

        expect(page).to have_content("#{customer.family_name} #{customer.given_name}")
        expect(page).to have_content('カルテ履歴')
        expect(page).to have_content('この来店のカルテはまだ作成されていません')
        expect(page).to have_link('カルテを作成する')
      end
    end

    context 'when cartes exist' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:charte) do # rubocop:disable RSpec/LetSetup
        create(:charte,
          stylist: stylist,
          customer: customer,
          reservation: paid_reservation,
          treatment_memo: 'テスト施術メモ',
          remarks: 'テスト備考')
      end

      it 'displays carte history' do
        visit stylists_customer_chartes_path(customer)

        expect(page).to have_content('テスト施術メモ')
        expect(page).to have_content('テスト備考')
        expect(page).to have_link('詳細を見る')
        expect(page).to have_link('編集する')
      end

      it 'displays menu names' do
        visit stylists_customer_chartes_path(customer)

        expect(page).to have_content('カット')
      end
    end
  end

  describe 'Create carte' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'can create a new carte' do
      visit stylists_customer_chartes_path(customer)

      click_on 'カルテを作成する'

      expect(page).to have_content('カルテ作成')
      expect(page).to have_content("#{customer.family_name} #{customer.given_name} 様")

      fill_in 'charte_treatment_memo', with: '新しい施術メモ'
      fill_in 'charte_remarks', with: '新しい備考'
      click_on 'カルテを作成する'

      expect(page).to have_content('カルテ詳細')
      expect(page).to have_content('新しい施術メモ')
      expect(page).to have_content('新しい備考')
    end

    it 'displays reservation info on new page' do
      visit new_stylists_charte_path(paid_reservation)

      expect(page).to have_content('対象の予約情報')
      expect(page).to have_content("#{customer.family_name} #{customer.given_name} 様")
      expect(page).to have_content('カット')
    end

    it 'can cancel carte creation' do
      visit new_stylists_charte_path(paid_reservation)

      click_on 'キャンセル'

      expect(page).to have_current_path(stylists_reservation_path(paid_reservation))
    end
  end

  describe 'Carte detail page' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:charte) do
      create(:charte,
        stylist: stylist,
        customer: customer,
        reservation: paid_reservation,
        treatment_memo: '詳細確認用メモ',
        remarks: '詳細確認用備考')
    end

    it 'displays carte details' do
      visit stylists_customer_charte_path(customer, charte)

      expect(page).to have_content('カルテ詳細')
      expect(page).to have_content('詳細確認用メモ')
      expect(page).to have_content('詳細確認用備考')
      expect(page).to have_content('施術メニュー')
      expect(page).to have_content('カット')
    end

    it 'provides edit and delete links' do
      visit stylists_customer_charte_path(customer, charte)

      expect(page).to have_link('編集')
      expect(page).to have_link('削除')
    end

    it 'can navigate back to history' do
      visit stylists_customer_charte_path(customer, charte)

      click_on '履歴に戻る'

      expect(page).to have_current_path(stylists_customer_chartes_path(customer))
    end
  end

  describe 'Edit carte' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:charte) do
      create(:charte,
        stylist: stylist,
        customer: customer,
        reservation: paid_reservation,
        treatment_memo: '編集前メモ',
        remarks: '編集前備考')
    end

    it 'can edit a carte' do
      visit stylists_customer_charte_path(customer, charte)

      click_on '編集'

      expect(page).to have_content('カルテ編集')

      fill_in 'charte_treatment_memo', with: '編集後メモ'
      fill_in 'charte_remarks', with: '編集後備考'
      click_on '変更を保存する'

      expect(page).to have_content('カルテ詳細')
      expect(page).to have_content('編集後メモ')
      expect(page).to have_content('編集後備考')
    end

    it 'can cancel edit' do
      visit edit_stylists_customer_charte_path(customer, charte)

      click_on 'キャンセル'

      expect(page).to have_current_path(stylists_customer_charte_path(customer, charte))
    end
  end

  describe 'Delete carte' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:charte) do
      create(:charte,
        stylist: stylist,
        customer: customer,
        reservation: paid_reservation,
        treatment_memo: '削除用メモ',
        remarks: '削除用備考')
    end

    it 'shows delete button with confirmation' do
      visit stylists_customer_charte_path(customer, charte)

      delete_link = find('a', text: '削除')
      expect(delete_link['data-turbo-confirm']).to eq('本当に削除しますか？')
      expect(delete_link['data-turbo-method']).to eq('delete')
    end
  end

  describe 'Access control' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:other_customer) do
      create(:user, role: :customer, family_name: '他', given_name: '顧客')
    end

    let!(:other_reservation) do
      create(:reservation, customer: other_customer, stylist: other_stylist, status: :paid,
        menu_ids: [other_menu.id], start_date_str: 1.month.ago.to_date.to_s, start_time_str: '14:00')
    end

    let!(:other_charte) do
      create(:charte,
        stylist: other_stylist,
        customer: other_customer,
        reservation: other_reservation,
        treatment_memo: '他のカルテ',
        remarks: '他の備考')
    end

    it 'prevents access to other stylists customer chartes' do
      visit stylists_customer_chartes_path(other_customer)

      expect(page).to have_current_path(stylists_dashboard_path)
    end

    it 'prevents viewing other stylists carte' do
      visit stylists_customer_charte_path(other_customer, other_charte)

      expect(page).to have_current_path(stylists_dashboard_path)
    end

    it 'prevents access from non-stylist users' do
      using_session('guest') do
        visit stylists_customer_chartes_path(customer)

        expect(page).to have_current_path(new_user_session_path)
      end
    end
  end

  describe 'Navigation' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'can navigate to dashboard from carte list' do
      visit stylists_customer_chartes_path(customer)

      click_on 'スタイリストトップへ戻る'

      expect(page).to have_current_path(stylists_dashboard_path)
    end

    it 'can navigate to customer list from carte list' do
      visit stylists_customer_chartes_path(customer)

      click_on '顧客一覧に戻る'

      expect(page).to have_current_path(stylists_customers_path)
    end
  end
end
