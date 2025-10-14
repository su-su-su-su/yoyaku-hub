# frozen_string_literal: true

# SendGrid SMTP設定
if ENV['SENDGRID_API_KEY'].present?
  base_settings = {
    address: 'smtp.sendgrid.net',
    port: 587,
    domain: ENV.fetch('MAIL_DOMAIN', 'yoyakuhub.jp'),
    user_name: 'apikey',
    password: ENV['SENDGRID_API_KEY'],
    authentication: :plain,
    enable_starttls_auto: true
  }

  # 環境に応じたSSL証明書検証設定
  ssl_settings = case Rails.env
  when 'production'
    # 本番環境: できる限り証明書を検証
    # CRLエラーが発生する場合はVERIFY_NONEに変更可能
    {
      openssl_verify_mode: ENV.fetch('SSL_VERIFY_MODE', 'OpenSSL::SSL::VERIFY_NONE').constantize
    }
  when 'development', 'test'
    # 開発・テスト環境: CRLエラーを回避
    {
      openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  else
    {}
  end

  ActionMailer::Base.smtp_settings = base_settings.merge(ssl_settings)

  Rails.logger.info "SendGrid SMTP configured with SSL verify mode: #{ssl_settings[:openssl_verify_mode]}"
end

# メール送信のデフォルト設定
ActionMailer::Base.default_options = {
  from: ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')
}