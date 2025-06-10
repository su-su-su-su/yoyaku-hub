# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe Schedule do
  let!(:stylist) { create(:user, :stylist) }
  let(:date) { Date.new(2025, 3, 25) }
  let(:schedule) { described_class.new(stylist.id, date) }

  before do
    allow(User).to receive(:find).with(stylist.id).and_return(stylist)
    allow(stylist).to receive(:holiday?).with(date).and_return(false)
  end

  describe 'initialization' do
    it 'sets stylist object and date' do
      expect(schedule.stylist).to eq(stylist)
      expect(schedule.date).to eq(date)
    end

    it 'checks for holiday on initialization by calling stylist.holiday?' do
      allow(stylist).to receive(:holiday?).with(date).and_return(false)

      described_class.new(stylist.id, date)

      expect(stylist).to have_received(:holiday?).with(date)
    end
  end

  describe '#holiday?' do
    context 'when it is a holiday (based on stylist.holiday? during init)' do
      before do
        allow(stylist).to receive(:holiday?).with(date).and_return(true)
      end

      it 'returns true' do
        expect(schedule).to be_holiday
      end
    end

    context 'when it is not a holiday (based on stylist.holiday? during init)' do
      it 'returns false' do
        expect(schedule).not_to be_holiday
      end
    end
  end

  describe '#working_hour' do
    context 'when it is a holiday' do
      before do
        allow(schedule).to receive(:holiday?).and_return(true)
      end

      it 'returns nil' do
        expect(schedule.working_hour).to be_nil
      end
    end

    context 'when it is not a holiday' do
      let(:working_hour) { instance_double(WorkingHour) }

      before do
        allow(schedule).to receive(:holiday?).and_return(false)
        allow(stylist).to receive(:working_hour_for_target_date).with(date).and_return(working_hour)
      end

      it 'returns the working hour' do
        expect(schedule.working_hour).to eq(working_hour)
      end

      it 'memoizes the result' do
        2.times { schedule.working_hour }

        expect(stylist).to have_received(:working_hour_for_target_date).with(date).once
      end
    end
  end

  describe '#time_slots' do
    context 'when it is a holiday' do
      before do
        allow(schedule).to receive(:holiday?).and_return(true)
      end

      it 'returns an empty array' do
        expect(schedule.time_slots).to eq([])
      end
    end

    context 'when working_hour is nil' do
      before do
        allow(schedule).to receive_messages(holiday?: false, working_hour: nil)
      end

      it 'returns an empty array' do
        expect(schedule.time_slots).to eq([])
      end
    end

    # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'when working_hour exists' do
      let(:working_hour) { instance_double(WorkingHour) }
      let(:hours) { { start: '09:00', end: '17:00' } }
      let(:time_options) { [['09:00', 0], ['09:30', 1], ['10:00', 2]] }
      let(:start_time) { Time.zone.parse('09:00') }
      let(:end_time) { Time.zone.parse('17:00') }

      before do
        allow(schedule).to receive_messages(holiday?: false, working_hour: working_hour)
        allow(WorkingHour).to receive(:formatted_hours).with(working_hour).and_return(hours)
        allow(Time.zone).to receive(:parse).and_return(nil)
        allow(Time.zone).to receive(:parse).with(hours[:start]).and_return(start_time)
        allow(Time.zone).to receive(:parse).with(hours[:end]).and_return(end_time)
        allow(WorkingHour).to receive(:generate_time_options_between)
          .with(start_time, end_time)
          .and_return(time_options)
      end

      it 'returns time slots' do
        expect(schedule.time_slots).to eq(['09:00', '09:30', '10:00'])
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#update_reservation_limit' do
    let(:slot_idx) { 10 }
    let(:limit) { instance_double(ReservationLimit, save: true) }
    let(:reservation_limits_relation_double) { instance_double(ActiveRecord::Relation) }

    before do
      allow(stylist).to receive(:reservation_limits).and_return(reservation_limits_relation_double)
      allow(reservation_limits_relation_double).to receive(:find_or_initialize_by)
        .with(target_date: date, time_slot: slot_idx)
        .and_return(limit)
    end

    context 'when direction is "up"' do
      it 'increments max_reservations' do
        stored_value = nil

        allow(limit).to receive(:max_reservations).and_return(nil, 0)
        allow(limit).to receive(:max_reservations=) do |value|
          stored_value = value
        end

        schedule.update_reservation_limit(slot_idx, 'up')

        expect(limit).to have_received(:save)
        expect(stored_value).to eq(1)
      end
    end

    context 'when direction is "down" and max_reservations is 0' do
      before do
        allow(limit).to receive(:max_reservations).and_return(0)
        allow(limit).to receive(:max_reservations=)
      end

      it 'does not decrement max_reservations' do
        schedule.update_reservation_limit(slot_idx, 'down')
        allow(limit).to receive(:max_reservations=)
        expect(limit).not_to have_received(:max_reservations=)
      end
    end

    context 'when direction is "down" and max_reservations is greater than 0' do
      before do
        allow(limit).to receive(:max_reservations).and_return(2)
        allow(limit).to receive(:max_reservations=)
      end

      it 'decrements max_reservations' do
        schedule.update_reservation_limit(slot_idx, 'down')
        expect(limit).to have_received(:max_reservations=).with(1)
        expect(limit).to have_received(:save)
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '.to_slot_index' do
    context 'when given a string' do
      it 'converts time string to slot index' do
        expect(described_class.to_slot_index('10:00')).to eq(20)
        expect(described_class.to_slot_index('10:30')).to eq(21)
      end
    end

    context 'when given a Time object' do
      it 'converts Time object to slot index' do
        time1 = Time.zone.parse('10:00')
        time2 = Time.zone.parse('10:30')
        expect(described_class.to_slot_index(time1)).to eq(20)
        expect(described_class.to_slot_index(time2)).to eq(21)
      end
    end

    context 'when given an unsupported type' do
      it 'raises an ArgumentError' do
        expect { described_class.to_slot_index(123) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#to_slot_index' do
    it 'delegates to the class method' do
      time_str = '10:30'
      allow(described_class).to receive(:to_slot_index).with(time_str).and_return(21)

      expect(schedule.to_slot_index(time_str)).to eq(21)
    end
  end

  describe '.safe_parse_date' do
    context 'when given a valid date string' do
      it 'returns the parsed date' do
        expect(described_class.safe_parse_date('2025-03-25')).to eq(Date.new(2025, 3, 25))
      end
    end

    context 'when given an invalid date string' do
      it 'returns the current date' do
        allow(Date).to receive(:current).and_return(Date.new(2025, 3, 25))
        expect(described_class.safe_parse_date('invalid')).to eq(Date.new(2025, 3, 25))
      end
    end
  end

  describe '#reservation_counts' do
    let(:reservations) do
      [
        instance_double(Reservation,
          start_at: Time.zone.parse("#{date} 10:00"),
          end_at: Time.zone.parse("#{date} 11:30")),
        instance_double(Reservation,
          start_at: Time.zone.parse("#{date} 11:00"),
          end_at: Time.zone.parse("#{date} 12:00"))
      ]
    end

    before do
      relation_for_stylist_reservations = instance_double(ActiveRecord::Relation)
      relation_after_date_filter = instance_double(ActiveRecord::Relation)
      where_chain_for_status = instance_double(ActiveRecord::QueryMethods::WhereChain)

      allow(stylist).to receive(:stylist_reservations).and_return(relation_for_stylist_reservations)
      allow(relation_for_stylist_reservations)
        .to receive(:where).with(start_at: date.all_day)
        .and_return(relation_after_date_filter)
      allow(relation_after_date_filter).to receive(:where).with(no_args).and_return(where_chain_for_status)
      allow(where_chain_for_status).to receive(:not).with(status: %i[canceled no_show]).and_return(reservations)

      allow(schedule).to receive(:to_slot_index).with(reservations[0].start_at).and_return(20)
      allow(schedule).to receive(:to_slot_index).with(reservations[0].end_at).and_return(23)
      allow(schedule).to receive(:to_slot_index).with(reservations[1].start_at).and_return(22)
      allow(schedule).to receive(:to_slot_index).with(reservations[1].end_at).and_return(24)
    end

    it 'returns a hash of slot indices to reservation counts' do
      counts = schedule.reservation_counts

      expect(counts).to be_a(Hash)
      expect(counts[20]).to eq(1)
      expect(counts[21]).to eq(1)
      expect(counts[22]).to eq(2)
      expect(counts[23]).to eq(1)
    end

    it 'memoizes the result' do
      allow(schedule).to receive(:slotwise_reservation_counts).and_call_original

      2.times { schedule.reservation_counts }

      expect(schedule).to have_received(:slotwise_reservation_counts).once
    end
  end

  describe '#reservation_limits' do
    let(:limits) do
      [
        instance_double(ReservationLimit, time_slot: 20, max_reservations: 2),
        instance_double(ReservationLimit, time_slot: 21, max_reservations: 1)
      ]
    end

    before do
      relation = instance_double(ActiveRecord::Relation)

      allow(stylist).to receive(:reservation_limits).and_return(relation)
      allow(relation).to receive(:where).with(target_date: date).and_return(relation)
      allow(relation).to receive(:find_each)
        .and_yield(limits[0])
        .and_yield(limits[1])
    end

    it 'returns a hash of slot indices to reservation limits' do
      limits_result = schedule.reservation_limits

      expect(limits_result).to be_a(Hash)
      expect(limits_result[20]).to eq(2)
      expect(limits_result[21]).to eq(1)
      expect(limits_result[22]).to eq(0)
    end

    it 'memoizes the result' do
      allow(schedule).to receive(:slotwise_reservation_limits).and_call_original

      2.times { schedule.reservation_limits }

      expect(schedule).to have_received(:slotwise_reservation_limits).once
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#reservations_map' do
    let(:reservations) do
      [
        instance_double(Reservation,
          id: 1,
          start_at: Time.zone.parse("#{date} 10:00"),
          end_at: Time.zone.parse("#{date} 11:30"),
          created_at: 2.hours.ago),
        instance_double(Reservation,
          id: 2,
          start_at: Time.zone.parse("#{date} 11:00"),
          end_at: Time.zone.parse("#{date} 12:00"),
          created_at: 1.hour.ago)
      ]
    end

    let(:relation_with_stylist) { instance_double(ActiveRecord::Relation, where: relation_with_status) }
    let(:relation_with_status) { instance_double(ActiveRecord::Relation, where: relation_with_date) }
    let(:relation_with_date) { instance_double(ActiveRecord::Relation, where: where_chain_for_start_at) }
    let(:where_chain_for_start_at) do
      instance_double(ActiveRecord::QueryMethods::WhereChain, not: relation_without_nil_start_at)
    end
    let(:relation_without_nil_start_at) { instance_double(ActiveRecord::Relation, where: where_chain_for_end_at) }
    let(:where_chain_for_end_at) do
      instance_double(ActiveRecord::QueryMethods::WhereChain, not: relation_without_nil_end_at)
    end
    let(:relation_without_nil_end_at) { instance_double(ActiveRecord::Relation, includes: reservations) }

    before do
      relation_for_stylist_reservations = instance_double(ActiveRecord::Relation)
      relation_after_status_filter = instance_double(ActiveRecord::Relation)
      relation_after_date_filter = instance_double(ActiveRecord::Relation)
      where_chain_for_start_at_not_nil = instance_double(ActiveRecord::QueryMethods::WhereChain)
      relation_after_start_at_not_nil = instance_double(ActiveRecord::Relation)
      where_chain_for_end_at_not_nil = instance_double(ActiveRecord::QueryMethods::WhereChain)
      relation_after_end_at_not_nil = instance_double(ActiveRecord::Relation)

      allow(stylist).to receive(:stylist_reservations).and_return(relation_for_stylist_reservations)
      allow(relation_for_stylist_reservations)
        .to receive(:where).with(status: %i[before_visit paid])
        .and_return(relation_after_status_filter)
      expected_start_time = date.beginning_of_day.in_time_zone
      expected_end_time = date.end_of_day.in_time_zone
      allow(relation_after_status_filter).to receive(:where)
        .with('start_at >= ? AND end_at <= ?', expected_start_time, expected_end_time)
        .and_return(relation_after_date_filter)
      allow(relation_after_date_filter).to receive(:where).with(no_args).and_return(where_chain_for_start_at_not_nil)
      allow(where_chain_for_start_at_not_nil)
        .to receive(:not).with(start_at: nil).and_return(relation_after_start_at_not_nil)
      allow(relation_after_start_at_not_nil).to receive(:where).with(no_args).and_return(where_chain_for_end_at_not_nil)
      allow(where_chain_for_end_at_not_nil).to receive(:not).with(end_at: nil).and_return(relation_after_end_at_not_nil)
      allow(relation_after_end_at_not_nil).to receive(:includes).with(:menus, :customer).and_return(reservations)

      allow(schedule).to receive(:to_slot_index).with(reservations[0].start_at).and_return(20)
      allow(schedule).to receive(:to_slot_index).with(reservations[1].start_at).and_return(22)
    end

    it 'returns a hash of slot indices to arrays of reservations' do
      map = schedule.reservations_map

      expect(map).to be_a(Hash)
      expect(map.default_proc).not_to be_nil
      expect(map[999]).to eq([])

      expect(map[20]).to be_an(Array)
      expect(map[20]).to include(reservations[0])
      expect(map[20].size).to eq(1)

      expect(map[21]).to be_an(Array)
      expect(map[21]).to be_empty

      expect(map[22]).to be_an(Array)
      expect(map[22]).to include(reservations[1])
      expect(map[22].size).to eq(1)

      expect(map[23]).to be_an(Array)
      expect(map[23]).to be_empty
    end

    it 'memoizes the result' do
      allow(schedule).to receive(:slotwise_reservations_map).and_call_original

      2.times { schedule.reservations_map }

      expect(schedule).to have_received(:slotwise_reservations_map).once
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
# rubocop:enable Metrics/BlockLength
