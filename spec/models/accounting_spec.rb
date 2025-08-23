# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting do
  describe 'validations and creation' do
    it 'has correct status enum values' do
      expect(described_class.statuses).to eq({ 'pending' => 0, 'completed' => 1 })
    end
  end

  describe 'associations' do
    it 'responds to reservation and accounting_payments' do
      accounting = described_class.new
      expect(accounting).to respond_to(:reservation, :accounting_payments)
    end

    it 'has many accounting_products' do
      accounting = described_class.new
      expect(accounting).to respond_to(:accounting_products)
      expect(accounting.class.reflect_on_association(:accounting_products).macro).to eq(:has_many)
      expect(accounting.class.reflect_on_association(:accounting_products).options[:dependent]).to eq(:destroy)
    end

    it 'has many products through accounting_products' do
      accounting = described_class.new
      expect(accounting).to respond_to(:products)
      expect(accounting.class.reflect_on_association(:products).macro).to eq(:has_many)
      expect(accounting.class.reflect_on_association(:products).options[:through]).to eq(:accounting_products)
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for accounting_products' do
      expect(described_class.nested_attributes_options[:accounting_products]).to be_present
      expect(described_class.nested_attributes_options[:accounting_products][:allow_destroy]).to be true
    end

    it 'rejects accounting_products without product_id' do
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      reservation = build(:reservation, stylist: stylist, customer: customer)
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation)

      accounting.accounting_products_attributes = [
        { product_id: nil, quantity: 1, actual_price: 1000 }
      ]

      expect { accounting.save! }.not_to change(AccountingProduct, :count)
    end
  end

  describe '#service_amount' do
    let(:setup) do
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      cut_menu = create(:menu, price: 3000, stylist: stylist)
      color_menu = create(:menu, price: 5000, stylist: stylist)
      reservation = build(:reservation, stylist: stylist, customer: customer, menus: [cut_menu, color_menu])
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation, total_amount: 10_000)
      { accounting: accounting }
    end
    let(:accounting) { setup[:accounting] }

    it 'returns the sum of menu prices' do
      expect(accounting.service_amount).to eq(8000)
    end
  end

  describe '#product_sales_amount' do
    let(:setup) do
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      reservation = build(:reservation, stylist: stylist, customer: customer)
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation)
      product_a = create(:product)
      product_b = create(:product)
      { accounting: accounting, product_a: product_a, product_b: product_b }
    end
    let(:accounting) { setup[:accounting] }
    let(:product_a) { setup[:product_a] }
    let(:product_b) { setup[:product_b] }

    before do
      create(:accounting_product, accounting: accounting, product: product_a, quantity: 2, actual_price: 3000)
      create(:accounting_product, accounting: accounting, product: product_b, quantity: 1, actual_price: 5000)
    end

    it 'returns the sum of product sales' do
      expect(accounting.product_sales_amount).to eq(11_000)
    end
  end

  describe '#total_with_products' do
    let(:stylist) do
      s = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: s, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      s
    end
    let(:customer) { create(:user, role: :customer) }
    let(:reservation) do
      r = build(:reservation, stylist: stylist, customer: customer)
      r.save(validate: false)
      r
    end
    let(:accounting) { create(:accounting, reservation: reservation, total_amount: 15_000) }

    it 'returns the total_amount' do
      expect(accounting.total_with_products).to eq(15_000)
    end
  end

  describe '#sales_breakdown' do
    let(:setup) do
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      menu = create(:menu, price: 8000, stylist: stylist)
      reservation = build(:reservation, stylist: stylist, customer: customer, menus: [menu])
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation, total_amount: 13_000)
      product = create(:product)
      { accounting: accounting, product: product }
    end
    let(:accounting) { setup[:accounting] }
    let(:product) { setup[:product] }

    before do
      create(:accounting_product, accounting: accounting, product: product, quantity: 1, actual_price: 5000)
    end

    it 'returns correct breakdown' do
      breakdown = accounting.sales_breakdown
      expect(breakdown[:service]).to eq(8000)
      expect(breakdown[:products]).to eq(5000)
      expect(breakdown[:total]).to eq(13_000)
    end
  end

  describe '#save_with_payments_and_products' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:today) { Date.parse('2025-08-25') } # Monday
    let(:stylist) do
      s = create(:user, role: :stylist)
      create(:working_hour,
        stylist: s,
        target_date: today,
        start_time: '09:00',
        end_time: '18:00')
      # 10:00と10:30のreservation_limitを設定
      create(:reservation_limit, stylist: s, target_date: today, time_slot: 20, max_reservations: 1) # 10:00
      create(:reservation_limit, stylist: s, target_date: today, time_slot: 21, max_reservations: 1) # 10:30
      s
    end
    let(:customer) { create(:user, role: :customer) }
    let(:menu) { create(:menu, stylist: stylist) }
    let(:reservation) do
      create(:reservation,
        stylist: stylist,
        customer: customer,
        start_at: Time.zone.parse("#{today} 10:00"),
        menus: [menu])
    end
    let(:accounting) { reservation.build_accounting(total_amount: 10_000) }
    let(:product) { create(:product) }

    context 'with valid data' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:payment_attributes) do
        { '0' => { payment_method: 'cash', amount: 10_000 } }
      end

      before do
        accounting.accounting_products_attributes = [
          { product_id: product.id, quantity: 1, actual_price: 3000 }
        ]
      end

      it 'saves accounting with payments and products' do
        expect(accounting.save_with_payments_and_products(payment_attributes)).to be true
        expect(accounting.accounting_payments.count).to eq(1)
        expect(accounting.accounting_products.count).to eq(1)
        expect(accounting).to be_completed
      end
    end

    context 'with invalid payment data' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:payment_attributes) { {} }

      it 'returns false and adds errors' do
        expect(accounting.save_with_payments_and_products(payment_attributes)).to be false
        expect(accounting.errors[:base]).to include('支払い情報を入力してください')
      end
    end
  end

  describe '#update_with_payments_and_products' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:today) { Date.parse('2025-08-25') } # Monday
    let(:stylist) do
      s = create(:user, role: :stylist)
      create(:working_hour,
        stylist: s,
        target_date: today,
        start_time: '09:00',
        end_time: '18:00')
      # 10:00と10:30のreservation_limitを設定
      create(:reservation_limit, stylist: s, target_date: today, time_slot: 20, max_reservations: 1) # 10:00
      create(:reservation_limit, stylist: s, target_date: today, time_slot: 21, max_reservations: 1) # 10:30
      s
    end
    let(:customer) { create(:user, role: :customer) }
    let(:menu) { create(:menu, stylist: stylist) }
    let(:reservation) do
      create(:reservation,
        stylist: stylist,
        customer: customer,
        start_at: Time.zone.parse("#{today} 10:00"),
        menus: [menu])
    end
    let(:accounting) { create(:accounting, :with_payment, reservation: reservation, total_amount: 10_000) }
    let(:product) { create(:product) }

    context 'with valid data' do # rubocop:disable RSpec/MultipleMemoizedHelpers
      let(:params) do
        {
          total_amount: 15_000,
          accounting_products_attributes: {
            '0' => { product_id: product.id, quantity: 2, actual_price: 2500 }
          }
        }
      end

      let(:payment_attributes) do
        { '0' => { payment_method: 'credit_card', amount: 15_000 } }
      end

      it 'updates accounting with new data' do
        expect(accounting.update_with_payments_and_products(params, payment_attributes)).to be true
        expect(accounting.reload.total_amount).to eq(15_000)
        expect(accounting.accounting_products.count).to eq(1)
        expect(accounting.accounting_payments.first.payment_method).to eq('credit_card')
      end
    end
  end
end
