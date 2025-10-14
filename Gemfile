# frozen_string_literal: true

source 'https://rubygems.org'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
ruby '3.4.4'
gem 'devise'
gem 'devise-i18n'
gem 'dotenv-rails'
gem 'rails', '~> 7.2.1', '>= 7.2.1.1'
gem 'rails-i18n'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 6.0'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"
gem 'cssbundling-rails'
gem 'jsbundling-rails'
# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

gem 'slim-rails'

gem 'csv'
gem 'holiday_jp'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'
gem 'rqrcode'
gem 'sassc-rails'
gem 'sendgrid-ruby'
gem 'simple_calendar'
gem 'whenever', require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'capybara'
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'factory_bot_rails'
  gem 'letter_opener_web'
  gem 'rspec-rails'
  gem 'selenium-webdriver'

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'bcrypt_pbkdf', '~> 1.0'
  gem 'capistrano', require: false
  gem 'capistrano3-puma', '~> 6.0', require: false
  gem 'capistrano-bundler', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rbenv', require: false
  gem 'ed25519', '~> 1.2'
  gem 'rubocop', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-fjord', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'slim_lint', require: false
  gem 'web-console'
end
