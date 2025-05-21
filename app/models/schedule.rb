# frozen_string_literal: true

class Schedule
  attr_reader :stylist_id, :date

  def initialize(stylist_id, date)
    @stylist_id = stylist_id
    @date = date
    @is_holiday = Holiday.default_for(stylist_id, date)
  end

  def holiday?
    @is_holiday.present?
  end

  def working_hour
    return nil if holiday?

    @working_hour ||= WorkingHour.date_only_for(stylist_id, date)
  end

  def time_slots
    return [] if holiday? || working_hour.nil?

    hours = WorkingHour.formatted_hours(working_hour)
    WorkingHour.generate_time_options_between(
      Time.zone.parse(hours[:start]),
      Time.zone.parse(hours[:end])
    ).map(&:first)
  end

  def reservation_counts
    @reservation_counts ||= slotwise_reservation_counts
  end

  def reservation_limits
    @reservation_limits ||= slotwise_reservation_limits
  end

  def reservations_map
    @reservations_map ||= slotwise_reservations_map
  end

  def update_reservation_limit(slot_idx, direction)
    limit = ReservationLimit.find_or_initialize_by(
      stylist_id: stylist_id,
      target_date: date,
      time_slot: slot_idx
    )
    limit.max_reservations ||= 0

    case direction
    when 'up'
      limit.max_reservations += 1
    when 'down'
      limit.max_reservations -= 1 if limit.max_reservations.positive?
    end

    limit.save
  end

  def self.to_slot_index(time_or_str)
    case time_or_str
    when String
      hour, minute = time_or_str.split(':').map(&:to_i)
    when Time, ActiveSupport::TimeWithZone
      hour = time_or_str.hour
      minute = time_or_str.min
    else
      raise ArgumentError, "Unsupported type: #{time_or_str.class}"
    end
    (hour * 2) + (minute >= 30 ? 1 : 0)
  end

  def to_slot_index(time_or_str)
    self.class.to_slot_index(time_or_str)
  end

  def self.safe_parse_date(date_string)
    Date.parse(date_string.to_s)
  rescue StandardError
    Date.current
  end

  private

  def slotwise_reservation_counts
    reservations = Reservation.where(stylist_id: stylist_id)
      .where(start_at: date.all_day)
      .where.not(status: %i[canceled no_show])

    counts = Hash.new(0)
    reservations.each do |res|
      start_slot = to_slot_index(res.start_at)
      end_slot = to_slot_index(res.end_at)
      (start_slot...end_slot).each do |slot_idx|
        counts[slot_idx] += 1
      end
    end
    counts
  end

  def slotwise_reservation_limits
    limits = Hash.new(0)
    ReservationLimit.where(stylist_id: stylist_id, target_date: date).find_each do |lim|
      limits[lim.time_slot] = lim.max_reservations
    end
    limits
  end

  def slotwise_reservations_map
    reservations = Reservation.where(stylist_id: stylist_id)
      .where(status: %i[before_visit paid])
      .where(
        'start_at >= ? AND end_at <= ?',
        date.beginning_of_day.in_time_zone,
        date.end_of_day.in_time_zone
      )
      .where.not(start_at: nil, end_at: nil)
      .includes(:menus, :customer)

    map = Hash.new { |h, k| h[k] = [] }

    reservations.each do |res|
      start_idx = to_slot_index(res.start_at)
      map[start_idx] << res
    end

    map.each_value do |reservations_in_slot|
      reservations_in_slot.sort_by!(&:created_at)
    end
    map
  end
end
