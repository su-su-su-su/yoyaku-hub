# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Accountings' do # rubocop:disable RSpec/MultipleMemoizedHelpers
  let(:stylist) { create(:user, :stylist) }
  let(:customer) { create(:customer, family_name: '山田', given_name: '太郎') }
  let(:cut_menu) { create(:menu, name: 'カット', price: 3000, duration: 60) }
  let(:color_menu) { create(:menu, name: 'カラー', price: 5000, duration: 60) }
  let(:today) { Date.current }
  let(:reservation) do
    create(:reservation,
      stylist: stylist,
      customer: customer,
      start_at: Time.zone.parse("#{today} 10:00"),
      menus: [cut_menu, color_menu])
  end

  def to_slot_index(time_str)
    h, m = time_str.split(':').map(&:to_i)
    (h * 2) + (m >= 30 ? 1 : 0)
  end

  before do
    create(:working_hour,
      stylist: stylist,
      target_date: today,
      start_time: '09:00',
      end_time: '19:00')

    ['10:00', '10:30', '11:00', '11:30', '12:00'].each do |time|
      create(:reservation_limit,
        stylist: stylist,
        target_date: today,
        time_slot: to_slot_index(time),
        max_reservations: 1)
    end

    sign_in stylist
  end

  describe 'new accounting process' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'with basic accounting process' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'can process payment with cash' do
        visit stylists_reservation_path(reservation)
        click_on '会計'

        expect(page).to have_content('会計処理')
        expect(page).to have_content('山田太郎 様')
        expect(page).to have_content('カット')
        expect(page).to have_content('カラー')

        expect(find_field('accounting[total_amount]').value).to eq '8000'

        within '.payment-method[data-payment-index="0"]' do
          select '現金', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          expect(find_field('accounting[accounting_payments_attributes][0][amount]').value).to eq '8000'
        end

        click_on '会計完了'

        expect(page).to have_content('会計が完了しました')
        expect(page).to have_current_path(stylists_reservation_path(reservation))

        accounting = reservation.reload.accounting
        expect(accounting).to be_completed
        expect(accounting.total_amount).to eq 8000
        expect(accounting.accounting_payments.count).to eq 1
        expect(accounting.accounting_payments.first.payment_method).to eq 'cash'
        expect(accounting.accounting_payments.first.amount).to eq 8000
      end

      it 'can process payment with modified amount' do
        visit new_stylists_accounting_path(id: reservation.id)

        fill_in 'accounting[total_amount]', with: '7000'

        within '.payment-method[data-payment-index="0"]' do
          select 'クレジットカード', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '7000'
        end

        click_on '会計完了'

        expect(page).to have_content('会計が完了しました')

        accounting = reservation.reload.accounting
        expect(accounting.total_amount).to eq 7000
        expect(accounting.accounting_payments.first.payment_method).to eq 'credit_card'
        expect(accounting.accounting_payments.first.amount).to eq 7000
      end
    end

    context 'with split payment using multiple methods' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'can split payment between cash and credit card', :js do
        visit new_stylists_accounting_path(id: reservation.id)

        within '.payment-method[data-payment-index="0"]' do
          select '現金', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '5000'
        end

        click_on '+ 支払方法を追加'

        within all('.payment-method').last do
          select 'クレジットカード', from: find('select')['name']
          fill_in find('input[type="number"]')['name'], with: '3000'
        end

        click_on '会計完了'

        expect(page).to have_content('会計が完了しました')

        accounting = reservation.reload.accounting
        expect(accounting.accounting_payments.count).to eq 2

        cash_payment = accounting.accounting_payments.find_by(payment_method: 'cash')
        expect(cash_payment.amount).to eq 5000

        credit_payment = accounting.accounting_payments.find_by(payment_method: 'credit_card')
        expect(credit_payment.amount).to eq 3000
      end

      it 'can split payment with 3 or more payment methods', :js do
        visit new_stylists_accounting_path(id: reservation.id)

        within '.payment-method[data-payment-index="0"]' do
          select '現金', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '3000'
        end

        click_on '+ 支払方法を追加'
        within all('.payment-method').last do
          select 'クレジットカード', from: find('select')['name']
          fill_in find('input[type="number"]')['name'], with: '3000'
        end
        click_on '+ 支払方法を追加'

        within all('.payment-method').last do
          select 'QR決済', from: find('select')['name']
          fill_in find('input[type="number"]')['name'], with: '2000'
        end

        click_on '会計完了'

        expect(page).to have_content('会計が完了しました')

        accounting = reservation.reload.accounting
        expect(accounting.accounting_payments.count).to eq 3
      end

      it 'can remove payment methods', :js do
        visit new_stylists_accounting_path(id: reservation.id)

        click_on '+ 支払方法を追加'
        expect(page).to have_css('.payment-method', count: 2)

        within all('.payment-method').last do
          click_on 'この支払方法を削除'
        end

        expect(page).to have_css('.payment-method', count: 1)
      end
    end

    context 'when validation errors occur' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'shows error when payment total does not match accounting amount' do
        visit new_stylists_accounting_path(id: reservation.id)

        within '.payment-method[data-payment-index="0"]' do
          select '現金', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '5000'
        end

        click_on '会計完了'

        expect(page).to have_content('支払い合計（¥5000）が会計金額（¥8000）と一致しません')
        expect(page).to have_current_path(%r{accountings/new})
      end

      it 'validates required payment method selection' do
        visit new_stylists_accounting_path(id: reservation.id)

        within '.payment-method[data-payment-index="0"]' do
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '8000'
        end

        select_element = find('select[name="accounting[accounting_payments_attributes][0][payment_method]"]')
        expect(select_element['required']).to be_present

        expect(page).to have_button('会計完了')
      end

      it 'shows error when payment amount is zero or less' do
        visit new_stylists_accounting_path(id: reservation.id)

        within '.payment-method[data-payment-index="0"]' do
          select '現金', from: 'accounting[accounting_payments_attributes][0][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '0'
        end

        click_on '会計完了'

        expect(page).to have_content('支払い金額は0より大きい値を入力してください')
      end
    end

    context 'when accounting is already completed' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:existing_accounting) do
        create(:accounting,
          reservation: reservation,
          total_amount: 8000,
          status: :completed)
      end

      it 'redirects to edit page' do
        visit new_stylists_accounting_path(id: reservation.id)

        expect(page).to have_current_path(edit_stylists_accounting_path(existing_accounting), ignore_query: true)
        expect(page).to have_content('会計修正')
        expect(find_field('accounting[total_amount]').value).to eq('8000')
      end
    end
  end

  describe 'accounting modification' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:accounting) do
      create(:accounting,
        reservation: reservation,
        total_amount: 8000,
        status: :completed)
    end

    before do
      create(:accounting_payment, accounting: accounting, payment_method: :cash, amount: 5000)
      create(:accounting_payment, accounting: accounting, payment_method: :credit_card, amount: 3000)
    end

    context 'with basic modifications' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'can modify accounting amount' do
        visit edit_stylists_accounting_path(accounting)

        expect(page).to have_content('会計修正')
        expect(page).to have_content('山田太郎 様')

        fill_in 'accounting[total_amount]', with: '7000'

        within '.payment-method[data-payment-index="0"]' do
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '4000'
        end

        within '.payment-method[data-payment-index="1"]' do
          fill_in 'accounting[accounting_payments_attributes][1][amount]', with: '3000'
        end

        click_on '会計修正完了'

        expect(page).to have_content('会計が修正されました')
        expect(page).to have_current_path(stylists_reservation_path(reservation))

        accounting.reload
        expect(accounting.total_amount).to eq 7000
        expect(accounting.accounting_payments.sum(:amount)).to eq 7000
      end

      it 'can change payment method' do
        visit edit_stylists_accounting_path(accounting)

        within '.payment-method[data-payment-index="0"]' do
          select 'QR決済', from: 'accounting[accounting_payments_attributes][0][payment_method]'
        end

        click_on '会計修正完了'

        expect(page).to have_content('会計が修正されました')

        accounting.reload
        expect(accounting.accounting_payments.find_by(amount: 5000).payment_method).to eq 'digital_pay'
      end
    end

    context 'when adding and removing payment methods' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'can add payment methods and modify', :js do
        visit edit_stylists_accounting_path(accounting)

        click_on '+ 支払方法を追加'

        within '.payment-method[data-payment-index="0"]' do
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '3000'
        end

        within '.payment-method[data-payment-index="1"]' do
          fill_in 'accounting[accounting_payments_attributes][1][amount]', with: '3000'
        end

        within '.payment-method[data-payment-index="2"]' do
          select 'その他', from: 'accounting[accounting_payments_attributes][2][payment_method]'
          fill_in 'accounting[accounting_payments_attributes][2][amount]', with: '2000'
        end

        click_on '会計修正完了'

        expect(page).to have_content('会計が修正されました')

        accounting.reload
        expect(accounting.accounting_payments.count).to eq 3
        expect(accounting.accounting_payments.find_by(payment_method: 'other').amount).to eq 2000
      end

      it 'can remove payment methods and modify', :js do
        visit edit_stylists_accounting_path(accounting)

        within '.payment-method[data-payment-index="1"]' do
          click_on 'この支払方法を削除'
        end

        within '.payment-method[data-payment-index="0"]' do
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '8000'
        end

        click_on '会計修正完了'

        expect(page).to have_content('会計が修正されました')

        accounting.reload
        expect(accounting.accounting_payments.count).to eq 1
        expect(accounting.accounting_payments.first.amount).to eq 8000
      end
    end

    context 'when validation errors occur' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      it 'shows error when payment total does not match accounting amount' do
        visit edit_stylists_accounting_path(accounting)

        within '.payment-method[data-payment-index="0"]' do
          fill_in 'accounting[accounting_payments_attributes][0][amount]', with: '3000'
        end

        click_on '会計修正完了'

        expect(page).to have_content('支払い合計（¥6000）が会計金額（¥8000）と一致しません')
        expect(page).to have_current_path(/accountings.*edit/)
      end
    end
  end

  describe 'accounting information display' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let!(:accounting) do
      create(:accounting,
        reservation: reservation,
        total_amount: 8000,
        status: :completed)
    end

    before do
      create(:accounting_payment, accounting: accounting, payment_method: :cash, amount: 3000)
      create(:accounting_payment, accounting: accounting, payment_method: :credit_card, amount: 3000)
      create(:accounting_payment, accounting: accounting, payment_method: :digital_pay, amount: 2000)
    end

    it 'can display accounting details' do
      visit stylists_accounting_path(accounting)

      expect(page).to have_content('会計詳細')
      expect(page).to have_content('山田太郎 様')
      expect(page).to have_content('¥8,000')

      expect(page).to have_content('現金')
      expect(page).to have_content('¥3000')

      expect(page).to have_content('クレジットカード')
      expect(page).to have_content('¥3000')

      expect(page).to have_content('QR決済')
      expect(page).to have_content('¥2000')
    end
  end

  describe 'navigation' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    it 'can return to reservation details with back button' do
      visit new_stylists_accounting_path(id: reservation.id)
      click_on '戻る'
      expect(page).to have_current_path(stylists_reservation_path(reservation))
    end

    context 'when modifying accounting' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let!(:accounting) { create(:accounting, reservation: reservation) }

      it 'can return to reservation details with back button' do
        visit edit_stylists_accounting_path(accounting)
        click_on '戻る'
        expect(page).to have_current_path(stylists_reservation_path(reservation))
      end
    end
  end
end
