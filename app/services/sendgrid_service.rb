# frozen_string_literal: true

require 'net/http'
require 'json'

class SendgridService
  def initialize
    @api_key = ENV['SENDGRID_API_KEY']
    @from_email = ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')
    @from_name = ENV.fetch('SENDGRID_FROM_NAME', 'YOYAKU HUB')
  end

  def send_email(to:, subject:, html_content:, text_content: nil)
    uri = URI('https://api.sendgrid.com/v3/mail/send')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # CRL取得エラーを回避

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'

    # メールデータを構築
    mail_data = {
      personalizations: [{
        to: [{ email: to }]
      }],
      from: {
        email: @from_email,
        name: @from_name
      },
      subject: subject,
      content: []
    }

    # テキストコンテンツを追加（存在する場合）
    if text_content
      mail_data[:content] << { type: 'text/plain', value: text_content }
    end

    # HTMLコンテンツを追加
    mail_data[:content] << { type: 'text/html', value: html_content }

    request.body = mail_data.to_json
    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      {
        success: true,
        status_code: response.code,
        body: response.body,
        headers: response.each_header.to_h,
        message_id: response['x-message-id']
      }
    else
      Rails.logger.error "SendGrid API Error: #{response.code} - #{response.body}"
      {
        success: false,
        status_code: response.code,
        body: response.body,
        error: parse_error(response)
      }
    end
  rescue => e
    Rails.logger.error "SendGrid Service Error: #{e.message}"
    { success: false, error: e.message }
  end

  def send_template_email(to:, subject:, template_data:)
    html_content = render_template(template_data)
    send_email(to: to, subject: subject, html_content: html_content)
  end

  private

  def parse_error(response)
    JSON.parse(response.body)['errors']&.first&.dig('message') rescue response.body
  end

  def render_template(template_data)
    # テンプレートレンダリングロジック（後で実装）
    template_data[:html] || '<p>No template provided</p>'
  end
end