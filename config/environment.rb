# frozen_string_literal: true

require 'dotenv/load' if File.exist?(File.expand_path('../../.env', __FILE__))

# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!
