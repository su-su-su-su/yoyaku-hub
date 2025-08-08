# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

server ENV['STAGING_SERVER_IP'] || 'your-server-ip', user: 'deploy', roles: %w{app db web}

# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

# role :app, %w{deploy@example.com}, my_property: :my_value
# role :web, %w{user1@primary.com user2@additional.com}, other_property: :other_value
# role :db,  %w{deploy@example.com}

# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
set :ssh_options, {
  keys: %w(~/.ssh/id_rsa),
  forward_agent: true,
  auth_methods: %w(publickey)
}

# Staging specific settings
set :rails_env, 'staging'
set :branch, ENV['BRANCH'] || 'develop'
set :deploy_to, '/var/www/yoyaku-hub-staging'

# Puma settings for staging
set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma-staging.sock"
set :puma_state, "#{shared_path}/tmp/pids/puma-staging.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma-staging.pid"
set :puma_access_log, "#{shared_path}/log/puma_staging_access.log"
set :puma_error_log, "#{shared_path}/log/puma_staging_error.log"
set :puma_service_unit_name, 'puma-yoyaku-hub-staging.service'

# Database settings
set :migration_role, :db

# Staging environment specific linked files
set :linked_files, fetch(:linked_files, []).push('config/credentials/staging.key', '.env.staging')

# Additional staging configurations
namespace :deploy do
  desc 'Seed the staging database'
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:seed'
        end
      end
    end
  end
  
  desc 'Copy production data to staging (use with caution)'
  task :copy_production_data do
    on roles(:db) do
      puts "This will overwrite the staging database with production data."
      puts "Are you sure? (y/N)"
      confirm = STDIN.gets.chomp
      if confirm.downcase == 'y'
        within release_path do
          with rails_env: 'production' do
            execute :pg_dump, 'yoyaku_hub_production', '>', '/tmp/production_backup.sql'
          end
          with rails_env: 'staging' do
            execute :psql, 'yoyaku_hub_staging', '<', '/tmp/production_backup.sql'
            execute :rm, '/tmp/production_backup.sql'
          end
        end
      end
    end
  end
end