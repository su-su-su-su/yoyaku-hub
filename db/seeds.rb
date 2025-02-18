# frozen_string_literal: true

puts "Seeding users..."
load Rails.root.join('db', 'seeds', 'users.rb')

puts "Seeding menus..."
load Rails.root.join('db', 'seeds', 'menus.rb')

puts "Seeding working_hours..."
load Rails.root.join('db', 'seeds', 'working_hours.rb')

puts "Seeding holidays..."
load Rails.root.join('db', 'seeds', 'holidays.rb')
