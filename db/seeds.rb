# frozen_string_literal: true

Dir.glob(Rails.root.join('db', 'seeds', '*.rb')).sort.each do |seed_file|
  puts "Loading seed: #{File.basename(seed_file)}"
  load seed_file
end
