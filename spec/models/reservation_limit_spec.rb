# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationLimit do
  describe 'associations' do
    let(:stylist) { create(:user, :stylist) }
    let(:reservation_limit) { create(:reservation_limit, stylist: stylist) }

    it 'belongs to a stylist' do
      expect(reservation_limit.stylist).to eq(stylist)
    end
  end

  describe 'validations' do
    it 'is valid with max_reservations' do
      reservation_limit = build(:reservation_limit, max_reservations: 1)
      expect(reservation_limit).to be_valid
    end

    it 'is valid with time_slot' do
      reservation_limit = build(:reservation_limit, max_reservations: 1, time_slot: 30)
      expect(reservation_limit).to be_valid
    end

    it 'is invalid without max_reservations' do
      reservation_limit = build(:reservation_limit, max_reservations: nil)
      expect(reservation_limit).not_to be_valid
      expect(reservation_limit.errors[:max_reservations]).to include('を入力してください')
    end

    it 'is invalid when max_reservations is not an integer' do
      reservation_limit = build(:reservation_limit, max_reservations: 1.5)
      expect(reservation_limit).not_to be_valid
      expect(reservation_limit.errors[:max_reservations]).to include('は整数で入力してください')
    end

    it 'is invalid when max_reservations is less than 0' do
      reservation_limit = build(:reservation_limit, max_reservations: -1)
      expect(reservation_limit).not_to be_valid
      expect(reservation_limit.errors[:max_reservations]).to include('は0以上の値にしてください')
    end

    it 'is invalid when max_reservations is greater than 2' do
      reservation_limit = build(:reservation_limit, max_reservations: 3)
      expect(reservation_limit).not_to be_valid
      expect(reservation_limit.errors[:max_reservations]).to include('は2以下の値にしてください')
    end

    it 'is valid when max_reservations is 0' do
      reservation_limit = build(:reservation_limit, max_reservations: 0)
      expect(reservation_limit).to be_valid
    end

    it 'is valid when max_reservations is 2' do
      reservation_limit = build(:reservation_limit, max_reservations: 2)
      expect(reservation_limit).to be_valid
    end
  end
end
