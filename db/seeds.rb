# frozen_string_literal: true

Rails.logger.debug 'Seeding users...'
load Rails.root.join('db/seeds/users.rb')

Rails.logger.debug 'Seeding menus...'
load Rails.root.join('db/seeds/menus.rb')

Rails.logger.debug 'Seeding holidays...'
load Rails.root.join('db/seeds/holidays.rb')

Rails.logger.debug 'Seeding working_hours...'
load Rails.root.join('db/seeds/working_hours.rb')

Rails.logger.debug 'Seeding reservation_limits...'
load Rails.root.join('db/seeds/reservation_limits.rb')

Rails.logger.debug 'Seeding shift_settings_date_based...'
load Rails.root.join('db/seeds/shift_settings_date_based.rb')

Rails.logger.debug 'Seeding reservations...'
load Rails.root.join('db/seeds/reservations.rb')

# Rails.logger.debug 'Seeding demo users...'
# load Rails.root.join('db/seeds/demo_users.rb')
# Note: Demo users are now created dynamically via User.find_or_create_demo_* methods
