# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# cronのログ出力先を設定
set :output, { standard: 'log/cron.log', error: 'log/cron_error.log' }

# 環境変数の設定
set :environment, ENV.fetch('RAILS_ENV', 'production')

# デモデータの日次クリーンアップ
# 毎日午前2時に実行
every 1.day, at: '2:00 am' do
  rake 'demo:daily_cleanup'
end

# 予約リマインダーメール送信
# 毎日午前11時（日本時間）に実行 - 明日の予約をリマインド
every 1.day, at: '11:00 am' do
  runner 'ReservationReminderJob.perform_later'
end

# バックアップタスク（さくらのオブジェクトストレージ契約後に有効化）
# # 日次バックアップ - 毎日午前3時
# every 1.day, at: '3:00 am' do
#   rake 'backup:daily'
# end
#
# # 週次バックアップ - 毎週日曜日の午前4時
# every :sunday, at: '4:00 am' do
#   rake 'backup:weekly'
# end
#
# # 月次バックアップ - 毎月1日の午前5時
# every '0 5 1 * *' do
#   rake 'backup:monthly'
# end