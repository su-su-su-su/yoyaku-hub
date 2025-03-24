# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkingHour do
  let(:stylist) { create(:user, role: :stylist) }
  let(:date) { Date.new(2023, 4, 1) }
  let(:working_hour) { build(:working_hour, stylist: stylist, target_date: date) }

  describe 'アソシエーション' do
    it 'belongs to a stylist' do
      expect(working_hour.stylist).to eq(stylist)
    end
  end

  describe 'バリデーション' do
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

  describe '.default_for' do
    context 'when a specific working hour exists for the date' do
      let!(:specific_wh) do
        create(:working_hour,
          stylist: stylist,
          target_date: date,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('19:00'))
      end

      it 'returns the specific working hour' do
        result = described_class.default_for(stylist.id, date)
        expect(result).to eq(specific_wh)
      end
    end

    context 'when the date is a holiday in Japan' do
      let(:holiday_date) { Date.new(2023, 1, 1) }
      let!(:holiday_wh) do
        create(:working_hour,
          stylist: stylist,
          day_of_week: 7,
          target_date: nil,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('15:00'))
      end

      before do
        allow(HolidayJp).to receive(:holiday?).with(holiday_date).and_return(true)
      end

      it 'returns the holiday working hour' do
        result = described_class.default_for(stylist.id, holiday_date)
        expect(result).to eq(holiday_wh)
      end
    end

    context 'when a default working hour exists for the day of week' do
      let!(:default_wh) do
        create(:working_hour,
          stylist: stylist,
          day_of_week: date.wday,
          target_date: nil,
          start_time: Time.zone.parse('11:00'),
          end_time: Time.zone.parse('20:00'))
      end

      it 'returns the default working hour for that day of week' do
        result = described_class.default_for(stylist.id, date)
        expect(result).to eq(default_wh)
      end
    end

    context 'when no working hour exists' do
      it 'returns a new working hour with default times' do
        result = described_class.default_for(stylist.id, date)
        expect(result).to be_a_new(described_class)
        expect(result.stylist_id).to eq(stylist.id)
        expect(result.target_date).to eq(date)
        expect(result.start_time.strftime('%H:%M')).to eq('09:00')
        expect(result.end_time.strftime('%H:%M')).to eq('18:00')
      end
    end
  end

  describe '.date_only_for' do
    it 'finds a working hour for a stylist and date' do
      wh = create(:working_hour, stylist: stylist, target_date: date)
      expect(described_class.date_only_for(stylist.id, date)).to eq(wh)
    end

    it 'returns nil if no working hour exists' do
      expect(described_class.date_only_for(stylist.id, date)).to be_nil
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

  describe '.time_options_for' do
    context 'when a working hour exists for the date' do
      before do
        create(:working_hour,
          stylist: stylist,
          target_date: date,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('14:00'))
      end

      it 'returns time options between the working hour start and end times' do
        options = described_class.time_options_for(stylist.id, date)
        expect(options).to eq([
                                ['10:00', '10:00'],
                                ['10:30', '10:30'],
                                ['11:00', '11:00'],
                                ['11:30', '11:30'],
                                ['12:00', '12:00'],
                                ['12:30', '12:30'],
                                ['13:00', '13:00'],
                                ['13:30', '13:30'],
                                ['14:00', '14:00']
                              ])
      end
    end

    context 'when no working hour exists for the date' do
      it 'returns time options between default start and end times' do
        options = described_class.time_options_for(stylist.id, date)
        first_option = options.first
        last_option = options.last
        expect(first_option).to eq(['09:00', '09:00'])
        expect(last_option).to eq(['18:00', '18:00'])
      end
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
