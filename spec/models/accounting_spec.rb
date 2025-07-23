# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting do
  describe 'basic creation' do
    it 'can be created with valid attributes' do
      reservation = Reservation.first
      skip 'No reservation data available' unless reservation

      accounting = described_class.new(
        reservation: reservation,
        total_amount: 5000,
        status: :pending
      )

      puts "Validation errors: #{accounting.errors.full_messages}" unless accounting.valid?

      expect(accounting.valid?).to be true
      expect(accounting.save).to be true
    end
  end

  describe 'enums' do
    it 'has correct status values' do
      expect(described_class.statuses).to eq({ 'pending' => 0, 'completed' => 1 })
    end
  end

  describe 'associations' do
    it 'belongs to reservation' do
      accounting = described_class.new
      expect(accounting).to respond_to(:reservation)
    end

    it 'has many accounting_payments' do
      accounting = described_class.new
      expect(accounting).to respond_to(:accounting_payments)
    end
  end
end
