# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting do
  describe 'validations and creation' do
    it 'can be created with valid attributes' do
      reservation = Reservation.first
      skip 'No reservation data available' unless reservation

      accounting = described_class.new(reservation: reservation, total_amount: 5000, status: :pending)
      expect(accounting).to be_valid
      expect(accounting.save).to be true
    end

    it 'has correct status enum values' do
      expect(described_class.statuses).to eq({ 'pending' => 0, 'completed' => 1 })
    end
  end

  describe 'associations' do
    it 'responds to reservation and accounting_payments' do
      accounting = described_class.new
      expect(accounting).to respond_to(:reservation, :accounting_payments)
    end
  end
end
