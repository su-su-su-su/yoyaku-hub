# frozen_string_literal: true

puts "Seeding users..."
load Rails.root.join('db', 'seeds', 'users.rb')

puts "Seeding menus..."
load Rails.root.join('db', 'seeds', 'menus.rb')

