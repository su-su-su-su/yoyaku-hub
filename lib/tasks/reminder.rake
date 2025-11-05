# frozen_string_literal: true

namespace :reminder do
  desc 'Send reservation reminder emails (for testing)'
  task send: :environment do
    puts '予約リマインダー送信処理を開始します...'
    ReservationReminderJob.perform_now
    puts '予約リマインダー送信処理が完了しました。'
  end

  desc 'Preview tomorrow reservations that will receive reminders'
  task preview: :environment do
    tomorrow = Date.tomorrow
    target_reservations = Reservation
      .where(start_at: tomorrow.all_day)
      .where(created_at: ...Date.current.beginning_of_day)
      .where(status: :before_visit)
      .includes(:customer, :stylist, :menus)

    puts "\n明日（#{tomorrow.strftime('%Y年%m月%d日')}）の予約で、リマインダー対象となる予約:"
    puts '=' * 60

    if target_reservations.empty?
      puts '対象予約はありません。'
    else
      target_reservations.each do |reservation|
        puts "\n予約ID: ##{reservation.id}"
        puts "  日時: #{reservation.start_at.strftime('%Y年%m月%d日 %H:%M')}"
        puts "  顧客: #{reservation.customer.family_name} #{reservation.customer.given_name} 様"
        puts "  メール: #{reservation.customer.email}"
        puts "  スタイリスト: #{reservation.stylist.family_name} #{reservation.stylist.given_name}"
        puts "  メニュー: #{reservation.menus.map(&:name).join(', ')}"
        puts "  作成日時: #{reservation.created_at.strftime('%Y年%m月%d日 %H:%M')}"

        puts '  ⚠️  デモ/ダミーユーザーのため送信をスキップします' if reservation.customer.demo_user? || reservation.customer.dummy_email?
      end
    end

    puts "\n#{'=' * 60}"
    puts "合計: #{target_reservations.count}件"
  end
end
