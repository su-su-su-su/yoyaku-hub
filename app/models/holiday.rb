class Holiday < ApplicationRecord
  belongs_to :stylist, class_name: 'User'
end
