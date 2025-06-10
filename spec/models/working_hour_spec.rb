# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe WorkingHour do
  let(:stylist) { create(:user, role: :stylist) }
  let(:date) { Date.new(2023, 4, 1) }
  let(:working_hour) { build(:working_hour, stylist: stylist, target_date: date) }

  describe 'associations' do
    it 'belongs to a stylist' do
      expect(working_hour.stylist).to eq(stylist)
    end
  end

  describe 'validations' do
    context 'when not a holiday' do
      before { working_hour.holiday_flag = '0' }

      it 'is valid when end_time is after start_time' do
        working_hour.start_time = Time.zone.parse('09:00')
        working_hour.end_time = Time.zone.parse('18:00')
        expect(working_hour).to be_valid
      end

      it 'is invalid when end_time is equal to start_time' do
        working_hour.start_time = Time.zone.parse('09:00')
        working_hour.end_time = Time.zone.parse('09:00')
        expect(working_hour).not_to be_valid
        expect(working_hour.errors[:end_time]).to include('は開始時間より後に設定してください')
      end

      it 'is invalid when end_time is before start_time' do
        working_hour.start_time = Time.zone.parse('18:00')
        working_hour.end_time = Time.zone.parse('09:00')
        expect(working_hour).not_to be_valid
        expect(working_hour.errors[:end_time]).to include('は開始時間より後に設定してください')
      end
    end

    context 'when a holiday' do
      before { working_hour.holiday_flag = '1' }

      it 'is valid even when end_time is equal to start_time' do
        working_hour.start_time = Time.zone.parse('00:00')
        working_hour.end_time = Time.zone.parse('00:00')
        expect(working_hour).to be_valid
      end

      it 'is valid even when end_time is before start_time' do
        working_hour.start_time = Time.zone.parse('18:00')
        working_hour.end_time = Time.zone.parse('09:00')
        expect(working_hour).to be_valid
      end
    end
  end

  describe '.full_time_options' do
    it 'returns 48 time options' do
      expect(described_class.full_time_options.size).to eq(48)
    end

    it 'includes all half-hour slots from 00:00 to 23:30' do
      options = described_class.full_time_options
      expect(options).to include(['00:00', '00:00'])
      expect(options).to include(['00:30', '00:30'])
      expect(options).to include(['12:00', '12:00'])
      expect(options).to include(['23:30', '23:30'])
    end
  end

  describe '.generate_time_options_between' do
    it 'generates time options between two times' do
      start_time = Time.zone.parse('09:00')
      end_time = Time.zone.parse('11:00')
      options = described_class.generate_time_options_between(start_time, end_time)
      expect(options).to eq([
                              ['09:00', '09:00'],
                              ['09:30', '09:30'],
                              ['10:00', '10:00'],
                              ['10:30', '10:30'],
                              ['11:00', '11:00']
                            ])
    end
  end

  describe '.formatted_hours' do
    context 'when working hour is present' do
      let(:wh) do
        build(:working_hour,
          start_time: Time.zone.parse('10:30'),
          end_time: Time.zone.parse('19:30'))
      end

      it 'returns formatted start and end times' do
        expect(described_class.formatted_hours(wh)).to eq(
          { start: '10:30', end: '19:30' }
        )
      end
    end

    context 'when working hour is nil' do
      it 'returns default formatted start and end times' do
        expect(described_class.formatted_hours(nil)).to eq(
          { start: '09:00', end: '18:00' }
        )
      end
    end
  end

  describe '#holiday_flag?' do
    it 'returns true when holiday_flag is "1"' do
      working_hour.holiday_flag = '1'
      expect(working_hour.holiday_flag?).to be true
    end

    it 'returns false when holiday_flag is "0"' do
      working_hour.holiday_flag = '0'
      expect(working_hour.holiday_flag?).to be false
    end

    it 'returns false when holiday_flag is nil' do
      working_hour.holiday_flag = nil
      expect(working_hour.holiday_flag?).to be false
    end
  end
end
# rubocop:enable Metrics/BlockLength
