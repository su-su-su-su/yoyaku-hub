# frozen_string_literal: true

threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
threads threads_count, threads_count

environment 'staging'

shared_dir = "/home/debian/yoyaku-hub-staging/shared"

bind "unix://#{shared_dir}/tmp/sockets/puma-staging.sock"

pidfile "#{shared_dir}/tmp/pids/puma-staging.pid"
state_path "#{shared_dir}/tmp/pids/puma-staging.state"

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

stdout_redirect "#{shared_dir}/log/puma.stdout.log", "#{shared_dir}/log/puma.stderr.log", true

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

plugin :tmp_restart
