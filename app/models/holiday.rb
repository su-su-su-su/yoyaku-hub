# frozen_string_literal: true

class Holiday < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
  scope :defaults, -> { where(target_date: nil).where.not(day_of_week: nil) }
end
