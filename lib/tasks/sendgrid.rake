# frozen_string_literal: true

namespace :sendgrid do
  desc 'SendGrid Web API テスト送信'
  task test: :environment do
    puts '=' * 60
    puts 'SendGrid Web API テスト'
    puts '=' * 60

    if ENV['SENDGRID_API_KEY'].blank?
      puts '❌ SENDGRID_API_KEY が設定されていません'
      exit
    end

    print '送信先メールアドレス: '
    to_email = $stdin.gets.chomp

    if to_email.blank?
      puts 'メールアドレスが入力されていません'
      exit
    end

    puts "\n送信中..."

    service = SendgridService.new

    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
        </head>
        <body>
          <h2>テスト送信成功</h2>
          <p>SendGrid Web APIが正常に動作しています。</p>
          <hr>
          <p style="color: #666; font-size: 12px;">
            送信日時: #{Time.current.strftime('%Y年%m月%d日 %H:%M:%S')}<br>
            From: #{ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')}
          </p>
        </body>
      </html>
    HTML

    text_content = <<~TEXT
      テスト送信成功

      SendGrid Web APIが正常に動作しています。

      送信日時: #{Time.current.strftime('%Y年%m月%d日 %H:%M:%S')}
      From: #{ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')}
    TEXT

    result = service.send_email(
      to: to_email,
      subject: 'YOYAKU HUB - テストメール',
      html_content: html_content,
      text_content: text_content
    )

    if result[:success]
      puts '✅ 送信成功！'
      puts "   Message-ID: #{result[:message_id]}" if result[:message_id]
    else
      puts "❌ 送信失敗: #{result[:error]}"
    end

    puts '=' * 60
  end

  desc 'SendGrid 設定確認'
  task check: :environment do
    puts '=' * 60
    puts 'SendGrid 設定確認'
    puts '=' * 60

    puts "APIキー: #{ENV['SENDGRID_API_KEY'].present? ? '✅ 設定済み' : '❌ 未設定'}"
    puts "送信元メール: #{ENV.fetch('SENDGRID_FROM_EMAIL', 'noreply@yoyakuhub.jp')}"
    puts "送信元名: #{ENV.fetch('SENDGRID_FROM_NAME', 'YOYAKU HUB')}"

    if ENV['SENDGRID_API_KEY'].present?
      puts "\nAPI接続テスト中..."

      require 'net/http'
      require 'json'

      uri = URI('https://api.sendgrid.com/v3/user/profile')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['SENDGRID_API_KEY']}"

      begin
        response = http.request(request)
        if response.code == '200'
          puts '✅ API接続: 成功'
        else
          puts "❌ API接続: 失敗 (#{response.code})"
        end
      rescue StandardError => e
        puts "❌ API接続: エラー (#{e.message})"
      end
    end

    puts '=' * 60
  end
end
