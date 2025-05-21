# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Schedule do
  let(:stylist_id) { 1 }
  let(:date) { Date.new(2025, 3, 25) }
  let(:schedule) { described_class.new(stylist_id, date) }

  describe 'initialization' do
    it 'sets stylist_id and date' do
      expect(schedule.stylist_id).to eq(stylist_id)
      expect(schedule.date).to eq(date)
    end

    it 'checks for holiday on initialization' do
      expect(Holiday).to receive(:default_for).with(stylist_id, date)
      described_class.new(stylist_id, date)
    end
  end

  describe '#holiday?' do
    context 'when it is a holiday' do
      before do
        allow(Holiday).to receive(:default_for).with(stylist_id, date).and_return(true)
      end

      it 'returns true' do
        expect(schedule).to be_holiday
      end
    end

    context 'when it is not a holiday' do
      before do
        allow(Holiday).to receive(:default_for).with(stylist_id, date).and_return(nil)
      end

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
      let(:working_hour) { double('WorkingHour') }

      before do
        allow(schedule).to receive(:holiday?).and_return(false)
        allow(WorkingHour).to receive(:date_only_for).with(stylist_id, date).and_return(working_hour)
      end

      it 'returns the working hour' do
        expect(schedule.working_hour).to eq(working_hour)
      end

      it 'memoizes the result' do
        expect(WorkingHour).to receive(:date_only_for).once.and_return(working_hour)
        2.times { schedule.working_hour }
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

    context 'when working_hour exists' do
      let(:working_hour) { double('WorkingHour') }
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
  end

  describe '#update_reservation_limit' do
    let(:slot_idx) { 10 }
    let(:limit) { double('ReservationLimit', max_reservations: nil, save: true) }

    before do
      allow(ReservationLimit).to receive(:find_or_initialize_by)
        .with(stylist_id: stylist_id, target_date: date, time_slot: slot_idx)
        .and_return(limit)
    end

    context 'when direction is "up"' do
      it 'increments max_reservations' do
        stored_value = nil

        allow(limit).to receive(:max_reservations) do
          stored_value
        end

        allow(limit).to receive(:max_reservations=) do |val|
          stored_value = val
        end

        expect(limit).to receive(:save)

        schedule.update_reservation_limit(slot_idx, 'up')

        expect(stored_value).to eq(1)
      end
    end

    context 'when direction is "down" and max_reservations is 0' do
      before do
        allow(limit).to receive(:max_reservations).and_return(0)
      end

      it 'does not decrement max_reservations' do
        expect(limit).not_to receive(:max_reservations=)
        schedule.update_reservation_limit(slot_idx, 'down')
      end
    end

    context 'when direction is "down" and max_reservations is greater than 0' do
      before do
        allow(limit).to receive(:max_reservations).and_return(2)
      end

      it 'decrements max_reservations' do
        expect(limit).to receive(:max_reservations=).with(1)
        schedule.update_reservation_limit(slot_idx, 'down')
      end
    end
  end

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
      expect(described_class).to receive(:to_slot_index).with(time_str).and_return(21)
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
      relation1 = double('relation1')
      relation2 = double('relation2')
      where_chain = double('where_chain')

      allow(Reservation).to receive(:where).with(stylist_id: stylist_id).and_return(relation1)
      allow(relation1).to receive(:where).with(start_at: date.all_day).and_return(relation2)
      allow(relation2).to receive(:where).and_return(where_chain)
      allow(where_chain).to receive(:not).with(status: %i[canceled no_show]).and_return(reservations)

      allow(reservations).to receive(:each).and_yield(reservations[0]).and_yield(reservations[1])

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
      allow(Reservation).to receive(:where).with(stylist_id: stylist_id).and_call_original

      2.times { schedule.reservation_counts }

      expect(Reservation).to have_received(:where).with(stylist_id: stylist_id).once
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
      allow(limits).to receive(:each).and_yield(limits[0]).and_yield(limits[1])
      relation = instance_double('ActiveRecord::RelationMock')
      allow(relation).to receive(:find_each) { |&block| limits.each(&block) }
      allow(ReservationLimit).to receive(:where).with(stylist_id: stylist_id, target_date: date).and_return(relation)
    end

    it 'returns a hash of slot indices to reservation limits' do
      limits_result = schedule.reservation_limits

      expect(limits_result).to be_a(Hash)
      expect(limits_result[20]).to eq(2)
      expect(limits_result[21]).to eq(1)
      expect(limits_result[22]).to eq(0)
    end

    it 'memoizes the result' do
      allow(ReservationLimit).to receive(:where).with(stylist_id: stylist_id, target_date: date).and_call_original

      2.times { schedule.reservation_limits }

      expect(ReservationLimit).to have_received(:where).with(stylist_id: stylist_id, target_date: date).once
    end
  end

  describe '#reservations_map' do
    let(:reservations) do
      [
        instance_double(Reservation,
                        id: 1,
                        start_at: Time.zone.parse("#{date} 10:00"),
                        end_at: Time.zone.parse("#{date} 11:30"),
                        created_at: Time.current - 2.hours),
        instance_double(Reservation,
                        id: 2,
                        start_at: Time.zone.parse("#{date} 11:00"),
                        end_at: Time.zone.parse("#{date} 12:00"),
                        created_at: Time.current - 1.hour)
      ]
    end

    before do
      relation1 = instance_double('ActiveRecord::RelationMock')
      relation2 = instance_double('ActiveRecord::RelationMock')
      relation3 = instance_double('ActiveRecord::RelationMock')
      where_chain = instance_double('ActiveRecord::WhereChainMock')
      relation4 = instance_double('ActiveRecord::RelationMock')

      allow(Reservation).to receive(:where).with(stylist_id: stylist_id).and_return(relation1)
      allow(relation1).to receive(:where).with(status: [:before_visit, :paid]).and_return(relation2)
      allow(relation2).to receive(:where).with(
        'start_at >= ? AND end_at <= ?',
        kind_of(ActiveSupport::TimeWithZone),
        kind_of(ActiveSupport::TimeWithZone)
      ).and_return(relation3)
      allow(relation3).to receive(:where).and_return(where_chain)
      allow(where_chain).to receive(:not).with(start_at: nil, end_at: nil).and_return(relation4)
      allow(relation4).to receive(:includes).with(:menus, :customer).and_return(reservations)

      allow(reservations).to receive(:each).and_yield(reservations[0]).and_yield(reservations[1])

      allow(schedule).to receive(:to_slot_index).with(reservations[0].start_at).and_return(20)
      allow(schedule).to receive(:to_slot_index).with(reservations[0].end_at).and_return(23)
      allow(schedule).to receive(:to_slot_index).with(reservations[1].start_at).and_return(22)
      allow(schedule).to receive(:to_slot_index).with(reservations[1].end_at).and_return(24)
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
      allow(Reservation).to receive(:where).with(stylist_id: stylist_id).and_call_original

      2.times { schedule.reservations_map }

      expect(Reservation).to have_received(:where).with(stylist_id: stylist_id).once
    end
  end
end
