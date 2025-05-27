# frozen_string_literal: true

FactoryBot.define do
  factory :reservation_menu_selection do
    reservation
    menu
  end
end
