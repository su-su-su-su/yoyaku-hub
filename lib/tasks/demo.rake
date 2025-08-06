# frozen_string_literal: true

namespace :demo do
  desc 'Reset demo users data'
  task reset: :environment do
    demo_users = User.where("email LIKE 'demo_stylist_%@example.com' OR email LIKE 'demo_customer_%@example.com'")

    demo_users.each do |user|
      user.reservations.destroy_all
      user.stylist_reservations.destroy_all

      user.stylist_chartes.destroy_all
      user.customer_chartes.destroy_all
    end

    demo_users.destroy_all

    puts "Demo users data has been reset (#{demo_users.count} users deleted)"
  end
end
