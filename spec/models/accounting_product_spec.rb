# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountingProduct do
  describe 'associations' do
    it 'belongs to accounting' do
      accounting_product = described_class.new
      expect(accounting_product).to respond_to(:accounting)
      expect(accounting_product.class.reflect_on_association(:accounting).macro).to eq(:belongs_to)
    end

    it 'belongs to product' do
      accounting_product = described_class.new
      expect(accounting_product).to respond_to(:product)
      expect(accounting_product.class.reflect_on_association(:product).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:product) { create(:product, user: user) }
    let(:accounting) do
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      reservation = build(:reservation, stylist: stylist, customer: customer)
      reservation.save(validate: false)
      create(:accounting, reservation: reservation)
    end

    it 'validates presence of quantity' do
      accounting_product = build(:accounting_product, accounting: accounting, product: product, quantity: nil)
      expect(accounting_product).not_to be_valid
      expect(accounting_product.errors[:quantity]).to include('を入力してください')
    end

    it 'validates quantity is greater than 0' do
      accounting_product = build(:accounting_product, accounting: accounting, product: product, quantity: 0)
      expect(accounting_product).not_to be_valid
      expect(accounting_product.errors[:quantity]).to include('は0より大きい値にしてください')

      accounting_product.quantity = 1
      expect(accounting_product).to be_valid
    end

    it 'validates presence of actual_price' do
      accounting_product = build(:accounting_product, accounting: accounting, product: product, actual_price: nil)
      expect(accounting_product).not_to be_valid
      expect(accounting_product.errors[:actual_price]).to include('を入力してください')
    end

    it 'validates actual_price is greater than or equal to 0' do
      accounting_product = build(:accounting_product, accounting: accounting, product: product, actual_price: -1)
      expect(accounting_product).not_to be_valid
      expect(accounting_product.errors[:actual_price]).to include('は0以上の値にしてください')

      accounting_product.actual_price = 0
      expect(accounting_product).to be_valid
    end
  end

  describe '#total_price' do
    let(:accounting_product) do
      user = create(:user)
      product = create(:product, user: user)
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      reservation = build(:reservation, stylist: stylist, customer: customer)
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation)
      build(:accounting_product, accounting: accounting, product: product, quantity: 2, actual_price: 3000)
    end

    it 'returns quantity * actual_price' do
      expect(accounting_product.total_price).to eq(6000)
    end
  end

  describe 'factory' do
    let(:setup) do
      user = create(:user)
      product = create(:product, user: user)
      stylist = create(:user, role: :stylist)
      (1..5).each do |day|
        create(:working_hour, stylist: stylist, day_of_week: day, start_time: '09:00', end_time: '18:00')
      end
      customer = create(:user, role: :customer)
      reservation = build(:reservation, stylist: stylist, customer: customer)
      reservation.save(validate: false)
      accounting = create(:accounting, reservation: reservation)
      { product: product, accounting: accounting }
    end
    let(:product) { setup[:product] }
    let(:accounting) { setup[:accounting] }

    it 'has a valid factory' do
      expect(build(:accounting_product, accounting: accounting, product: product)).to be_valid
    end

    it 'has a discounted trait' do
      accounting_product = build(:accounting_product, :discounted, accounting: accounting, product: product)
      expect(accounting_product.actual_price).to eq(2000)
    end

    it 'has a multiple trait' do
      accounting_product = build(:accounting_product, :multiple, accounting: accounting, product: product)
      expect(accounting_product.quantity).to eq(3)
    end
  end
end
