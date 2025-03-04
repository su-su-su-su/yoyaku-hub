# frozen_string_literal: true

require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

puts 'FactoryBot configuration in spec_helper.rb'
puts "Methods loaded: #{FactoryBot.methods.include?(:build)}"
