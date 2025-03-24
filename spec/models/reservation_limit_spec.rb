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

  describe '.default_for' do
    let(:stylist) { create(:user, :stylist) }
    let(:date) { Date.current }

    context 'when global setting has time_slot' do
      before do
        @global_reservation_limit = create(:reservation_limit, stylist: stylist, target_date: nil, max_reservations: 0,
          time_slot: 60)
      end

      it 'inherits time_slot value from global settings to new instance' do
        result = described_class.default_for(stylist.id, date)
        expect(result.time_slot).to eq(60)
      end
    end

    context 'when reservation limit exists for a specific date' do
      let!(:reservation_limit) { create(:reservation_limit, stylist: stylist, target_date: date, max_reservations: 2) }

      it 'returns existing reservation limit' do
        result = described_class.default_for(stylist.id, date)
        expect(result).to eq(reservation_limit)
      end
    end

    context 'when no specific date limit exists but global setting exists' do
      let!(:global_reservation_limit) do
        create(:reservation_limit, stylist: stylist, target_date: nil, max_reservations: 0)
      end

      it 'returns new instance based on global settings' do
        result = described_class.default_for(stylist.id, date)

        expect(result).to be_a_new(described_class)
        expect(result.stylist_id).to eq(stylist.id)
        expect(result.target_date).to eq(date)
        expect(result.max_reservations).to eq(global_reservation_limit.max_reservations)
      end
    end
  end
end
