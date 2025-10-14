# frozen_string_literal: true

# Railsコンソールでメールをテストする方法
# rails console でこのコードを実行

# 1. 予約確認メールのテスト
reservation = Reservation.last # または特定の予約を取得
mailer = ReservationMailer.new
result = mailer.reservation_confirmation(reservation)
puts result[:success] ? '送信成功' : "送信失敗: #{result[:error]}"

# 2. キャンセル通知メールのテスト
result = mailer.cancellation_confirmation(reservation)
puts result[:success] ? '送信成功' : "送信失敗: #{result[:error]}"

# 3. 美容師への通知テスト
result = mailer.new_reservation_notification(reservation)
puts result[:success] ? '送信成功' : "送信失敗: #{result[:error]}"

# 4. 予約変更通知のテスト
changes = { start_at: true, menus: true }
result = mailer.reservation_updated_notification(reservation, changes)
puts result[:success] ? '送信成功' : "送信失敗: #{result[:error]}"
