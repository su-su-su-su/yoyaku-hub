# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "yoyaku-hub"
set :repo_url, "git@github.com:su-su-su-su/yoyaku-hub.git"

# Default branch is :master
set :branch, ENV['BRANCH'] || 'main'

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/credentials/production.key', '.env')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system', 'public/uploads', 'node_modules')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
set :ssh_options, verify_host_key: :secure
set :rbenv_type, :user
set :rbenv_ruby, '3.4.4'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"

set :rbenv_map_bins, %w{rake gem bundle ruby rails puma pumactl yarn node}

set :bundle_path, -> { shared_path.join('bundle') }
set :bundle_flags, '--quiet'
set :bundle_jobs, 2
set :bundle_config, {
  'deployment' => 'true',
  'without' => 'development test'
}

# Rails settings
set :rails_env, 'production'
set :assets_roles, [:web, :app]
set :migration_role, :db

# Puma settings
set :puma_role, :app
set :puma_threads, [2, 8]
set :puma_workers, ENV.fetch("WEB_CONCURRENCY") { 2 }
set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{shared_path}/log/puma_access.log"
set :puma_error_log, "#{shared_path}/log/puma_error.log"
set :puma_preload_app, true
set :puma_init_active_record, true
set :puma_systemctl_user, :system
set :puma_service_unit_name, 'puma-yoyaku-hub.service'
set :puma_enable_lingering, false

append :linked_dirs, 'log', 'tmp/pids', 'tmp/sockets', 'public/system', 'vendor/bundle'
