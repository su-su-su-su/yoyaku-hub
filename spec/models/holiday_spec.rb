# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Holiday do
  let(:stylist) { create(:user, role: :stylist) }

  describe 'アソシエーション' do
    let(:holiday) { create(:holiday, stylist: stylist) }

    it 'belongs to a stylist' do
      expect(holiday.stylist).to eq(stylist)
    end
  end

  describe '.default_for' do
    let(:target_date) { Date.new(2025, 3, 5) }

    context 'with specific date holiday settings' do
      it 'when is_holiday is true, returns true' do
        create(:holiday, stylist: stylist, target_date: target_date, is_holiday: true)
        expect(described_class.default_for(stylist.id, target_date)).to be true
      end

      it 'when is_holiday is false, returns false' do
        create(:holiday, stylist: stylist, target_date: target_date, is_holiday: false)
        expect(described_class.default_for(stylist.id, target_date)).to be false
      end
    end

    context 'when no specific date setting and the date is a Japanese holiday' do
      let(:holiday_date) { Date.new(2025, 1, 1) }

      before do
        allow(HolidayJp).to receive(:holiday?).with(holiday_date).and_return(true)
      end

      it 'with holiday settings, returns the holiday setting' do
        create(:holiday, stylist: stylist, day_of_week: 7, target_date: nil, is_holiday: true)
        expect(described_class.default_for(stylist.id, holiday_date)).to be true
      end

      it 'with weekday settings but no holiday settings, applies the weekday setting' do
        wday = holiday_date.wday
        create(:holiday, stylist: stylist, day_of_week: wday, target_date: nil)
        expect(described_class.default_for(stylist.id, holiday_date)).to be true
      end
    end

    context 'when no specific date setting and the date is not a holiday' do
      before do
        allow(HolidayJp).to receive(:holiday?).with(target_date).and_return(false)
      end

      it 'with weekday settings, returns true' do
        wday = target_date.wday
        create(:holiday, stylist: stylist, day_of_week: wday, target_date: nil)
        expect(described_class.default_for(stylist.id, target_date)).to be true
      end

      it 'without weekday settings, returns false' do
        expect(described_class.default_for(stylist.id, target_date)).to be false
      end
    end
  end
end
