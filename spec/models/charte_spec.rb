# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Charte do
  let(:stylist) { create(:stylist) }
  let(:customer) { create(:customer) }
  let(:charte) { create(:charte, stylist: stylist, customer: customer) }

  describe 'associations' do
    it 'belongs to stylist' do
      expect(charte.stylist).to eq(stylist)
    end

    it 'belongs to customer' do
      expect(charte.customer).to eq(customer)
    end

    it 'belongs to reservation' do
      expect(charte.reservation).to be_present
    end
  end

  describe 'validations' do
    it 'validates presence of stylist' do
      invalid_charte = described_class.new(customer: customer, treatment_memo: 'test')
      invalid_charte.valid?
      expect(invalid_charte.errors[:stylist]).to include('を入力してください')
    end

    it 'validates presence of customer' do
      invalid_charte = described_class.new(stylist: stylist, treatment_memo: 'test')
      invalid_charte.valid?
      expect(invalid_charte.errors[:customer]).to include('を入力してください')
    end

    it 'validates presence of reservation' do
      invalid_charte = described_class.new(stylist: stylist, customer: customer, treatment_memo: 'test')
      invalid_charte.valid?
      expect(invalid_charte.errors[:reservation]).to include('を入力してください')
    end

    it 'validates uniqueness of reservation_id' do
      existing_charte = create(:charte)
      new_charte = build(:charte, reservation: existing_charte.reservation)
      expect(new_charte).not_to be_valid
      expect(new_charte.errors[:reservation_id]).to include('はすでに存在します')
    end

    it 'validates length of treatment_memo' do
      long_text = 'a' * 256
      invalid_charte = build(:charte, stylist: stylist, customer: customer, treatment_memo: long_text)
      invalid_charte.valid?
      expect(invalid_charte.errors[:treatment_memo]).to include('は255文字以内で入力してください')
    end

    it 'validates length of remarks' do
      long_text = 'a' * 256
      invalid_charte = build(:charte, stylist: stylist, customer: customer, remarks: long_text)
      invalid_charte.valid?
      expect(invalid_charte.errors[:remarks]).to include('は255文字以内で入力してください')
    end
  end

  describe 'scopes' do
    let(:another_stylist) { create(:stylist) }
    let(:another_customer) { create(:customer) }

    before do
      @first_charte = create(:charte, stylist: stylist, customer: customer)
      @second_charte = create(:charte, stylist: another_stylist, customer: another_customer)
    end

    # rubocop:disable RSpec/InstanceVariable
    describe '.for_stylist' do
      it 'returns chartes for the specified stylist' do
        expect(described_class.for_stylist(stylist)).to include(@first_charte)
        expect(described_class.for_stylist(stylist)).not_to include(@second_charte)
      end
    end
    # rubocop:enable RSpec/InstanceVariable

    # rubocop:disable RSpec/InstanceVariable
    describe '.for_customer' do
      it 'returns chartes for the specified customer' do
        expect(described_class.for_customer(customer)).to include(@first_charte)
        expect(described_class.for_customer(customer)).not_to include(@second_charte)
      end
    end
    # rubocop:enable RSpec/InstanceVariable

    # rubocop:disable RSpec/InstanceVariable
    describe '.recent' do
      it 'returns chartes ordered by created_at desc' do
        expect(described_class.recent.first).to eq(@second_charte)
        expect(described_class.recent.second).to eq(@first_charte)
      end
    end
    # rubocop:enable RSpec/InstanceVariable
  end

  describe '#menu_names' do
    let(:cut_menu) { create(:menu, name: 'カット', stylist: stylist) }
    let(:color_menu) { create(:menu, name: 'カラー', stylist: stylist) }

    it 'returns menu names from the reservation' do
      reservation_with_menus = build(:reservation, stylist: stylist, customer: customer)
      reservation_with_menus.menu_ids = [cut_menu.id, color_menu.id]
      reservation_with_menus.save!(validate: false)

      charte_with_menus = create(:charte, stylist: stylist, customer: customer, reservation: reservation_with_menus)
      expect(charte_with_menus.menu_names).to contain_exactly('カット', 'カラー')
    end
  end

  describe '#reservation_date' do
    it 'returns the start_at from the reservation' do
      expect(charte.reservation_date).to eq(charte.reservation.start_at)
    end
  end

  describe '#total_amount' do
    context 'when accounting is completed' do
      before do
        create(:accounting, :completed, reservation: charte.reservation, total_amount: 8000)
      end

      it 'returns the total amount from accounting' do
        expect(charte.total_amount).to eq(8000)
      end
    end

    context 'when accounting is not completed' do
      before do
        create(:accounting, reservation: charte.reservation, status: :pending)
      end

      it 'returns nil' do
        expect(charte.total_amount).to be_nil
      end
    end

    context 'when accounting does not exist' do
      it 'returns nil' do
        expect(charte.total_amount).to be_nil
      end
    end
  end

  describe '#accounting_products' do
    let(:product_a) { create(:product, name: 'シャンプー') }
    let(:product_b) { create(:product, name: 'トリートメント') }

    context 'when accounting is completed with products' do
      before do
        accounting = create(:accounting, :completed, reservation: charte.reservation)
        create(:accounting_product, accounting: accounting, product: product_a, quantity: 2, actual_price: 3000)
        create(:accounting_product, accounting: accounting, product: product_b, quantity: 1, actual_price: 5000)
      end

      it 'returns the accounting products' do
        products = charte.accounting_products
        expect(products.count).to eq(2)
        expect(products.map(&:product).map(&:name)).to contain_exactly('シャンプー', 'トリートメント')
      end
    end

    context 'when accounting is completed without products' do
      before do
        create(:accounting, :completed, reservation: charte.reservation)
      end

      it 'returns an empty array' do
        expect(charte.accounting_products).to eq([])
      end
    end

    context 'when accounting is not completed' do
      before do
        accounting = create(:accounting, reservation: charte.reservation, status: :pending)
        create(:accounting_product, accounting: accounting, product: product_a, quantity: 1, actual_price: 3000)
      end

      it 'returns an empty array' do
        expect(charte.accounting_products).to eq([])
      end
    end

    context 'when accounting does not exist' do
      it 'returns an empty array' do
        expect(charte.accounting_products).to eq([])
      end
    end
  end

  describe '#has_products?' do
    let(:product) { create(:product, name: 'ヘアオイル') }

    context 'when accounting has products' do
      before do
        accounting = create(:accounting, :completed, reservation: charte.reservation)
        create(:accounting_product, accounting: accounting, product: product, quantity: 1, actual_price: 4000)
      end

      it 'returns true' do
        expect(charte.has_products?).to be true
      end
    end

    context 'when accounting has no products' do
      before do
        create(:accounting, :completed, reservation: charte.reservation)
      end

      it 'returns false' do
        expect(charte.has_products?).to be false
      end
    end

    context 'when accounting is not completed' do
      before do
        accounting = create(:accounting, reservation: charte.reservation, status: :pending)
        create(:accounting_product, accounting: accounting, product: product, quantity: 1, actual_price: 4000)
      end

      it 'returns false' do
        expect(charte.has_products?).to be false
      end
    end

    context 'when accounting does not exist' do
      it 'returns false' do
        expect(charte.has_products?).to be false
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
