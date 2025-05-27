# frozen_string_literal: true

class Holiday < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
end
