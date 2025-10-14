# frozen_string_literal: true

# アプリケーションのベースURL設定
# 環境変数 BASE_URL が設定されていない場合は、環境ごとのデフォルト値を使用
Rails.application.config.base_url = if ENV['BASE_URL'].present?
                                      ENV['BASE_URL']
                                    elsif Rails.env.production?
                                      # 本番環境のURL（環境変数で設定してください）
                                      ENV.fetch('BASE_URL', 'https://yoyaku-hub.com')
                                    elsif Rails.env.staging?
                                      # ステージング環境のURL（環境変数で設定してください）
                                      ENV.fetch('BASE_URL', 'https://staging.yoyaku-hub.com')
                                    else
                                      # 開発環境
                                      'http://localhost:3000'
                                    end