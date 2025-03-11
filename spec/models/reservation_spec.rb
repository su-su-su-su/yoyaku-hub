# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reservation do
  let(:customer) { create(:user, role: :customer) }
  let(:stylist) { create(:user, role: :stylist) }
  let(:short_menu) { create(:menu, stylist: stylist, duration: 30, is_active: true) }
  let(:long_menu) { create(:menu, stylist: stylist, duration: 60, is_active: true) }

  def setup_working_hour(start_time: '09:00', end_time: '17:00')
    create(:working_hour,
           stylist: stylist,
           day_of_week: Date.current.wday,
           start_time: Time.zone.parse(start_time),
           end_time: Time.zone.parse(end_time))
  end

  def build_test_reservation(attrs = {})
    defaults = {
      customer: customer,
      stylist: stylist,
      start_date_str: Date.current.to_s,
      start_time_str: '10:00',
      menu_ids: [short_menu.id, long_menu.id]
    }

    build(:reservation, defaults.merge(attrs))
  end

  before do
    working_hour = setup_working_hour
    allow(WorkingHour).to receive(:date_only_for).and_return(working_hour)
    allow(ReservationLimit).to receive(:find_by).and_return(
      instance_double(ReservationLimit, max_reservations: 1)
    )
  end

  describe 'アソシエーション' do
    let(:reservation) { create(:reservation, customer: customer, stylist: stylist) }

    it 'belongs to customer' do
      expect(reservation.customer).to eq(customer)
    end

    it 'belongs to stylist' do
      expect(reservation.stylist).to eq(stylist)
    end

    it 'has many reservation_menu_selections' do
      selection = create(:reservation_menu_selection, reservation: reservation, menu: short_menu)
      expect(reservation.reservation_menu_selections).to include(selection)
    end

    it 'has many menus through reservation_menu_selections' do
      create(:reservation_menu_selection, reservation: reservation, menu: short_menu)
      create(:reservation_menu_selection, reservation: reservation, menu: long_menu)

      reservation.reload

      expect(reservation.menus).to include(short_menu)
      expect(reservation.menus).to include(long_menu)
    end
  end

  describe 'enum' do
    it 'defines correct status values' do
      expect(described_class.statuses.keys).to match_array(%w[before_visit paid canceled no_show])
      expect(described_class.statuses.values).to contain_exactly(0, 1, 2, 3)
    end
  end

  describe 'バリデーション' do
    context 'with valid attributes' do
      it 'is valid' do
        reservation = build_test_reservation
        expect(reservation).to be_valid
      end
    end

    context 'when on a holiday' do
      it 'is invalid when WorkingHour is nil' do
        allow(WorkingHour).to receive(:date_only_for).and_return(nil)
        reservation = build_test_reservation
        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include('選択した日にちは休業日です')
      end

      it 'is invalid when working hours start and end time are the same' do
        closed_hours = instance_double(WorkingHour,
                                       start_time: Time.zone.parse('09:00'),
                                       end_time: Time.zone.parse('09:00'))
        allow(WorkingHour).to receive(:date_only_for).and_return(closed_hours)

        reservation = build_test_reservation
        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include('選択した日にちは休業日です')
      end
    end

    context 'with times outside operating hours' do
      it 'is invalid when start time is before operating hours' do
        reservation = build_test_reservation(start_time_str: '08:00')
        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include('予約開始時刻が営業時間より早いです')
      end

      it 'is invalid when end time is after operating hours' do
        reservation = build_test_reservation(start_time_str: '16:00')
        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include('施術終了時刻が営業時間を超えています')
      end
    end

    context 'when slot capacity is exceeded' do
      it 'is invalid when a time slot exceeds capacity' do
        limit = build_stubbed(:reservation_limit,
                              stylist: stylist,
                              target_date: Date.current,
                              time_slot: 20,
                              max_reservations: 0)

        allow(ReservationLimit).to receive(:find_by).and_return(nil)
        allow(ReservationLimit).to receive(:find_by)
          .with(stylist_id: stylist.id, target_date: Date.current, time_slot: 20)
          .and_return(limit)

        reservation = build_test_reservation
        expect(reservation).not_to be_valid
        expect(reservation.errors[:base]).to include('この時間帯は既に受付上限を超えています。')
      end
    end

    context 'without menu selections' do
      it 'is invalid without menu selections' do
        reservation = described_class.new(
          customer: customer,
          stylist: stylist,
          start_date_str: Date.current.to_s,
          start_time_str: '10:00',
          menu_ids: []
        )
        expect(reservation).not_to be_valid
        expect(reservation.errors[:menus]).to include('は1つ以上選択してください')
      end

      it 'is invalid with only blank menu selections' do
        reservation = described_class.new(
          customer: customer,
          stylist: stylist,
          start_date_str: Date.current.to_s,
          start_time_str: '10:00',
          menu_ids: ['']
        )
        expect(reservation).not_to be_valid
        expect(reservation.errors[:menus]).to include('は1つ以上選択してください')
      end
    end
  end

  describe 'callbacks' do
    describe '#combine_date_and_time' do
      let(:reservation) { build_test_reservation }

      it 'combines date and time to set start_at' do
        reservation.valid?

        expected_time = Time.zone.parse("#{Date.current} 10:00")
        expect(reservation.start_at).to be_within(1.second).of(expected_time)
      end

      it 'calculates end_at based on menu durations' do
        reservation.valid?

        expected_end = reservation.start_at + 90.minutes
        expect(reservation.end_at).to be_within(1.second).of(expected_end)
      end

      it 'uses custom_duration if provided' do
        reservation.custom_duration = 120
        reservation.valid?

        expected_end = reservation.start_at + 120.minutes
        expect(reservation.end_at).to be_within(1.second).of(expected_end)
      end

      it 'does nothing if date or time is missing' do
        incomplete_reservation = described_class.new(
          customer: customer,
          stylist: stylist,
          menu_ids: [short_menu.id]
        )

        expect { incomplete_reservation.valid? }.not_to raise_error
        expect(incomplete_reservation.start_at).to be_nil
        expect(incomplete_reservation.end_at).to be_nil
      end
    end
  end

  describe '.find_next_reservation_start_slot' do
    let(:date) { Date.current }

    it 'returns the next reservation start slot from given time' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(described_class).to receive(:where).with(stylist_id: stylist.id).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(status: %i[before_visit paid]).and_return(mock_relation)

      reservations = [
        instance_double(described_class, start_at: Time.zone.parse("#{date} 10:00")),
        instance_double(described_class, start_at: Time.zone.parse("#{date} 14:00"))
      ]

      allow(mock_relation).to receive(:where).with(start_at: date.all_day).and_return(reservations)

      expect(described_class.find_next_reservation_start_slot(stylist.id, date, 18)).to eq(20)

      expect(described_class.find_next_reservation_start_slot(stylist.id, date, 22)).to eq(28)

      expect(described_class.find_next_reservation_start_slot(stylist.id, date, 30)).to eq(34)
    end

    it 'returns the end of day slot when there are no reservations' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(described_class).to receive(:where).with(stylist_id: stylist.id).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(status: %i[before_visit paid]).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(start_at: date.all_day).and_return([])

      expect(described_class.find_next_reservation_start_slot(stylist.id, date, 20)).to eq(34)
    end
  end

  describe '.find_previous_reservation_end_slot' do
    let(:date) { Date.current }

    it 'returns the previous reservation end slot from given time' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(described_class).to receive(:where).with(stylist_id: stylist.id).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(status: %i[before_visit paid]).and_return(mock_relation)

      reservations = [
        instance_double(described_class, end_at: Time.zone.parse("#{date} 11:00")),
        instance_double(described_class, end_at: Time.zone.parse("#{date} 15:00"))
      ]

      allow(mock_relation).to receive(:where).with(start_at: date.all_day).and_return(reservations)

      expect(described_class.find_previous_reservation_end_slot(stylist.id, date, 24)).to eq(22)

      expect(described_class.find_previous_reservation_end_slot(stylist.id, date, 32)).to eq(30)
    end

    it 'returns the start of day slot when there are no reservations' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(described_class).to receive(:where).with(stylist_id: stylist.id).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(status: %i[before_visit paid]).and_return(mock_relation)
      allow(mock_relation).to receive(:where).with(start_at: date.all_day).and_return([])

      expect(described_class.find_previous_reservation_end_slot(stylist.id, date, 24)).to eq(18)
    end
  end

  describe '.to_slot_index' do
    it 'converts time to slot index' do
      expect(described_class.to_slot_index(Time.zone.parse('10:00'))).to eq(20)
      expect(described_class.to_slot_index(Time.zone.parse('10:30'))).to eq(21)
      expect(described_class.to_slot_index(Time.zone.parse('11:15'))).to eq(22)
    end
  end
end
