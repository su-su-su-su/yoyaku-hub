# frozen_string_literal: true

class WorkingHour < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
  attr_accessor :holiday_flag

  DEFAULT_START_TIME = '09:00'
  DEFAULT_END_TIME = '18:00'

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time, unless: :holiday_flag?

  def self.full_time_options
    (0..47).map do |i|
      hour = i / 2
      minute = (i % 2) * 30
      time_str = format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
      [time_str, time_str]
    end
  end

  def self.generate_time_options_between(start_time, end_time)
    time_options = []
    current_time = start_time

    while current_time <= end_time
      formatted = current_time.strftime('%H:%M')
      time_options << [formatted, formatted]
      current_time += 30.minutes
    end

    time_options
  end

  def self.formatted_hours(working_hour)
    if working_hour.present?
      {
        start: working_hour.start_time.strftime('%H:%M'),
        end: working_hour.end_time.strftime('%H:%M')
      }
    else
      { start: DEFAULT_START_TIME, end: DEFAULT_END_TIME }
    end
  end

  def holiday_flag?
    ['1', true].include?(holiday_flag)
  end

  private

  def end_time_after_start_time
    return unless start_time >= end_time

    errors.add(:end_time, 'は開始時間より後に設定してください')
  end
end
