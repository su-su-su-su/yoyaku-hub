# frozen_string_literal: true

Devise.setup do |config|
  config.mailer_sender = ENV['MAILER_SENDER']

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
