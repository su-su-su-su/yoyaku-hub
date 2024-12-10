# frozen_string_literal: true

class ReservationLimit < ApplicationRecord
  belongs_to :stylist, class_name: 'User'

  validates :max_reservations, presence: true,
                               numericality: {
                                 only_integer: true,
                                 greater_than_or_equal_to: 0,
                                 less_than_or_equal_to: 2
                               }
end
