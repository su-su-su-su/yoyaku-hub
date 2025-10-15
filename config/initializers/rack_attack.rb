# frozen_string_literal: true

class Rack::Attack
  # Rack::Attackを有効化
  # 注意: キャッシュストアを設定する必要があります
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### 信頼できるIPアドレス（ホワイトリスト）###
  # ローカル環境は制限しない
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  ### スロットリング（レート制限） ###

  # 1. 一般的なリクエストの制限
  # IPアドレスごとに1秒間に5リクエストまで
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # 2. ログイン試行の制限（IPアドレスベース）
  # 同じIPアドレスから5分間に5回までのログイン試行を許可
  throttle('logins/ip', limit: 5, period: 5.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      req.ip
    end
  end

  # 3. ログイン試行の制限（メールアドレスベース）
  # 同じメールアドレスで20分間に5回までのログイン試行を許可
  throttle('logins/email', limit: 5, period: 20.minutes) do |req|
    if req.path == '/users/sign_in' && req.post?
      # params[:user][:email] を取得して正規化
      req.params.dig('user', 'email').to_s.downcase.gsub(/\s+/, '')
    end
  end

  # 4. パスワードリセットの制限
  throttle('password_resets/ip', limit: 3, period: 1.hour) do |req|
    if req.path == '/users/password' && req.post?
      req.ip
    end
  end

  # 5. アカウント登録の制限
  throttle('registrations/ip', limit: 3, period: 1.hour) do |req|
    if req.path.match?(%r{/users/sign_up}) && req.post?
      req.ip
    end
  end

  ### ブロックリスト（特定のIPアドレスを拒否） ###
  # 環境変数で設定したIPアドレスをブロック
  # 例: BLOCKED_IPS="192.168.1.1,10.0.0.1"
  blocklist('block-malicious-ips') do |req|
    blocked_ips = ENV.fetch('BLOCKED_IPS', '').split(',').map(&:strip)
    blocked_ips.include?(req.ip)
  end

  ### レート制限に達した場合のカスタムレスポンス ###
  self.blocklisted_responder = lambda do |_request|
    [403, { 'Content-Type' => 'text/html' }, ['<html><body><h1>アクセスが拒否されました</h1><p>不審なアクティビティが検出されたため、アクセスがブロックされました。</p></body></html>']]
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'Content-Type' => 'text/html',
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + (match_data[:period] - (now % match_data[:period]))).to_s
    }

    [429, headers, ['<html><body><h1>リクエストが多すぎます</h1><p>しばらく時間をおいてから再度お試しください。</p></body></html>']]
  end

  ### ロギング ###
  ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, payload|
    req = payload[:request]
    if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
      Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type']} - IP: #{req.ip}, Path: #{req.path}"
    end
  end
end
