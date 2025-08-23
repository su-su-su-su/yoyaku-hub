# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product do
  describe 'associations' do
    it 'belongs to user' do
      product = described_class.new
      expect(product).to respond_to(:user)
      expect(product.class.reflect_on_association(:user).macro).to eq(:belongs_to)
    end

    it 'has many accounting_products' do
      product = described_class.new
      expect(product).to respond_to(:accounting_products)
      expect(product.class.reflect_on_association(:accounting_products).macro).to eq(:has_many)
      expect(product.class.reflect_on_association(:accounting_products).options[:dependent]).to eq(:restrict_with_error)
    end

    it 'has many accountings through accounting_products' do
      product = described_class.new
      expect(product).to respond_to(:accountings)
      expect(product.class.reflect_on_association(:accountings).macro).to eq(:has_many)
      expect(product.class.reflect_on_association(:accountings).options[:through]).to eq(:accounting_products)
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      product = build(:product, name: nil)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to include('を入力してください')
    end

    it 'validates presence of default_price' do
      product = build(:product, default_price: nil)
      expect(product).not_to be_valid
      expect(product.errors[:default_price]).to include('を入力してください')
    end

    it 'validates default_price is greater than or equal to 0' do
      product = build(:product, default_price: -1)
      expect(product).not_to be_valid
      expect(product.errors[:default_price]).to include('は0以上の値にしてください')

      product.default_price = 0
      expect(product).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_product) { create(:product, active: true) }
    let!(:inactive_product) { create(:product, :inactive) }

    describe '.active' do
      it 'returns only active products' do
        expect(described_class.active).to include(active_product)
        expect(described_class.active).not_to include(inactive_product)
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:product)).to be_valid
    end

    it 'has an inactive trait' do
      product = build(:product, :inactive)
      expect(product.active).to be false
    end

    it 'has an expensive trait' do
      product = build(:product, :expensive)
      expect(product.default_price).to eq(10_000)
    end
  end
end
