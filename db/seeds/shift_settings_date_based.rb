# frozen_string_literal: true

require 'factory_bot_rails'

start_date = Time.zone.today.beginning_of_month
end_date = Time.zone.today.end_of_month

# rubocop:disable Metrics/BlockLength
User.where(role: 1).find_each do |stylist|
  (start_date..end_date).each do |date|
    effective_wday = date.wday
    effective_wday = 7 if HolidayJp.holiday?(date)

    holiday = Holiday.find_by(stylist_id: stylist.id, target_date: date)
    if holiday&.is_holiday
      start_str = '00:00'
      end_str = '00:00'
      flag = '1'
    else
      template = WorkingHour.find_by(
        stylist_id: stylist.id,
        target_date: nil,
        day_of_week: effective_wday
      )
      next unless template

      start_str = template.start_time.strftime('%H:%M')
      end_str = template.end_time.strftime('%H:%M')
      flag = template.holiday_flag
    end

    daily_record = WorkingHour.find_or_initialize_by(
      stylist_id: stylist.id,
      target_date: date
    )

    daily_record.assign_attributes(
      start_time: Time.zone.parse(start_str),
      end_time: Time.zone.parse(end_str),
      holiday_flag: flag
    )

    if daily_record.persisted?
      daily_record.update(
        start_time: Time.zone.parse(start_str),
        end_time: Time.zone.parse(end_str),
        holiday_flag: flag
      )
    else
      daily_record.save!(validate: false)
    end
    next unless daily_record.start_time && daily_record.end_time

    start_slot = (daily_record.start_time.hour * 2) + (daily_record.start_time.min >= 30 ? 1 : 0)
    end_slot = (daily_record.end_time.hour * 2) + (daily_record.end_time.min >= 30 ? 1 : 0)
    (start_slot...end_slot).each do |slot|
      rl_slot = ReservationLimit.find_or_initialize_by(
        stylist_id: stylist.id,
        target_date: date,
        time_slot: slot
      )
      rl_slot.max_reservations = (flag == '1' ? 0 : 1)
      rl_slot.save!
    end
  end
end
# rubocop:enable Metrics/BlockLength
