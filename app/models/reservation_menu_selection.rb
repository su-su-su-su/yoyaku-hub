# frozen_string_literal: true

class ReservationMenuSelection < ApplicationRecord
  belongs_to :menu
  belongs_to :reservation
end
