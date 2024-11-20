class Menu < ApplicationRecord
  belongs_to :stylist, class_name: 'User', foreign_key: 'stylist_id'

  validates :name, presence: true, uniqueness: { scope: :stylist_id }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration, presence: true, numericality: { greater_than_or_equal_to: 0 }
  scope :by_stylist, ->(stylist) { where(stylist_id: stylist.id) }
end
