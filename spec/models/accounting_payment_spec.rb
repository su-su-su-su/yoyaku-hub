# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountingPayment do
  describe 'enums' do
    it 'has correct payment_method values' do
      expected_values = { 'cash' => 0, 'credit_card' => 1, 'digital_pay' => 2, 'other' => 3 }
      expect(described_class.payment_methods).to eq(expected_values)
    end
  end

  describe 'associations' do
    it 'belongs to accounting' do
      payment = described_class.new
      expect(payment).to respond_to(:accounting)
    end
  end
end
