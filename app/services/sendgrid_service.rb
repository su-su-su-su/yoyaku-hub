# frozen_string_literal: true

require 'net/http'
require 'json'

class SendgridService
  def initialize
    @api_key = ENV.fetch('SENDGRID_API_KEY', nil)
    @from_email = ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')
    @from_name = ENV.fetch('SENDGRID_FROM_NAME', 'YOYAKU HUB')
  end

  def send_email(to:, subject:, html_content:, text_content: nil)
    request = build_request(to: to, subject: subject, html_content: html_content, text_content: text_content)
    response = execute_request(request)
    handle_response(response)
  rescue StandardError => e
    Rails.logger.error "SendGrid Service Error: #{e.message}"
    { success: false, error: e.message }
  end

  def send_template_email(to:, subject:, template_data:)
    html_content = render_template(template_data)
    send_email(to: to, subject: subject, html_content: html_content)
  end

  private

  def build_request(to:, subject:, html_content:, text_content:)
    uri = URI('https://api.sendgrid.com/v3/mail/send')
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    mail_data = build_mail_data(to: to, subject: subject, html_content: html_content, text_content: text_content)
    request.body = mail_data.to_json
    request
  end

  def build_mail_data(to:, subject:, html_content:, text_content:)
    {
      personalizations: [{ to: [{ email: to }] }],
      from: { email: @from_email, name: @from_name },
      subject: subject,
      content: build_content(html_content: html_content, text_content: text_content)
    }
  end

  def build_content(html_content:, text_content:)
    content = []
    content << { type: 'text/plain', value: text_content } if text_content
    content << { type: 'text/html', value: html_content }
    content
  end

  def execute_request(request)
    uri = URI('https://api.sendgrid.com/v3/mail/send')
    http = configure_http(uri)
    http.request(request)
  end

  def configure_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # CRL取得エラーを回避
    http
  end

  def handle_response(response)
    if success_response?(response)
      build_success_response(response)
    else
      build_error_response(response)
    end
  end

  def success_response?(response)
    response.code.to_i >= 200 && response.code.to_i < 300
  end

  def build_success_response(response)
    {
      success: true,
      status_code: response.code,
      body: response.body,
      headers: response.each_header.to_h,
      message_id: response['x-message-id']
    }
  end

  def build_error_response(response)
    Rails.logger.error "SendGrid API Error: #{response.code} - #{response.body}"
    {
      success: false,
      status_code: response.code,
      body: response.body,
      error: parse_error(response)
    }
  end

  def parse_error(response)
    JSON.parse(response.body)['errors']&.first&.dig('message')
  rescue StandardError
    response.body
  end

  def render_template(template_data)
    # テンプレートレンダリングロジック（後で実装）
    template_data[:html] || '<p>No template provided</p>'
  end
end
