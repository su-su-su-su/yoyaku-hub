# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')
  layout 'mailer'
end
