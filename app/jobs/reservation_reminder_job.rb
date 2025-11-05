# frozen_string_literal: true

class ReservationReminderJob < ApplicationJob
  queue_as :default

  def perform
    target_reservations = fetch_target_reservations
    Rails.logger.info "予約リマインダー処理開始: #{target_reservations.count}件の対象予約"

    target_reservations.find_each do |reservation|
      process_reservation(reservation)
    end

    Rails.logger.info '予約リマインダー処理完了'
  end

  private

  def fetch_target_reservations
    tomorrow = Date.tomorrow
    Reservation
      .where(start_at: tomorrow.all_day)
      .where(created_at: ...Date.current.beginning_of_day) # 本日0時より前に作成
      .where(status: :before_visit) # 来店前ステータスの予約のみ
      .includes(:customer, :stylist, :menus) # N+1クエリを防ぐ
  end

  def process_reservation(reservation)
    if skip_notification?(reservation)
      Rails.logger.info "デモ/ダミーユーザーのためスキップ: Reservation##{reservation.id}"
      return
    end

    send_reminder(reservation)
  end

  def skip_notification?(reservation)
    reservation.customer.demo_user? || reservation.customer.dummy_email?
  end

  def send_reminder(reservation)
    ReservationMailer.new.reminder_email(reservation)
    Rails.logger.info "リマインダーメール送信成功: Reservation##{reservation.id}"
  rescue StandardError => e
    Rails.logger.error "リマインダーメール送信失敗: Reservation##{reservation.id} - #{e.message}"
    # エラーが発生しても他の予約の処理は続行
  end
end
