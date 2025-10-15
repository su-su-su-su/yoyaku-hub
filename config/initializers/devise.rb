# frozen_string_literal: true

Devise.setup do |config|
  config.mailer_sender = ENV.fetch('MAILER_SENDER', ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp'))

  require 'devise/orm/active_record'

  config.case_insensitive_keys = [:email]

  config.strip_whitespace_keys = [:email]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.reconfirmable = true

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 8..128

  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.reset_password_within = 6.hours

  # アカウントロック設定
  # 5回失敗したらアカウントをロック
  config.maximum_attempts = 5
  # ロック解除方法: :time（一定時間後に自動解除）、:email（メールで解除）、:both（両方）
  config.lock_strategy = :failed_attempts
  # :time の場合の自動解除時間（15分）
  config.unlock_in = 15.minutes
  # アンロック方法: :both（メールでも時間経過でも解除可能）
  config.unlock_strategy = :both
  # ロック解除用のキー
  config.unlock_keys = [:email]

  # セッションタイムアウトの設定
  config.timeout_in = :timeout_in

  config.scoped_views = true

  config.sign_out_via = :delete

  config.responder.error_status = :unprocessable_entity

  config.responder.redirect_status = :see_other

  config.omniauth :google_oauth2,
                Rails.application.credentials.dig(:google_oauth2, :client_id),
                Rails.application.credentials.dig(:google_oauth2, :client_secret),
                {
                   scope: 'email, profile',
                   prompt: 'select_account'
                }
end
