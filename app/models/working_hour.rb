# frozen_string_literal: true

class WorkingHour < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  private

  def end_time_after_start_time
    return unless start_time >= end_time

    errors.add(:end_time, 'は開始時間より後に設定してください')
  end
end
