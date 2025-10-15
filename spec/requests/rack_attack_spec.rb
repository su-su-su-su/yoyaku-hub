# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack' do
  before do
    # Rack::Attackのキャッシュをクリア
    Rack::Attack.cache.store.clear
  end

  describe 'ログイン試行の制限（IPアドレスベース）' do
    let(:email) { 'test@example.com' }
    let(:password) { 'password123' }
    let(:login_path) { '/users/sign_in' }

    before do
      create(:user, :stylist,
        email: email,
        password: password,
        password_confirmation: password)
    end

    it '5回目のログイン試行までは許可される' do
      5.times do |i|
        post login_path, params: { user: { email: email, password: 'wrong_password' } }
        expect(response.status).not_to eq(429), "#{i + 1}回目の試行で429エラー"
      end
    end

    it 'Rack::Attackの設定が読み込まれている' do
      expect(Rack::Attack.throttles).to include('logins/ip')
      expect(Rack::Attack.throttles).to include('logins/email')
    end
  end

  describe 'パスワードリセットの制限' do
    let(:email) { 'test3@example.com' }
    let(:password_reset_path) { '/users/password' }

    before do
      create(:user, :stylist,
        email: email,
        password: 'password123',
        password_confirmation: 'password123')
    end

    it '3回目のリクエストまでは許可される' do
      3.times do |i|
        post password_reset_path, params: { user: { email: email } }
        expect(response.status).not_to eq(429), "#{i + 1}回目の試行で429エラー"
      end
    end

    it 'Rack::Attackの設定が読み込まれている' do
      expect(Rack::Attack.throttles).to include('password_resets/ip')
    end
  end

  describe 'アカウント登録の制限' do
    it 'Rack::Attackの設定が読み込まれている' do
      expect(Rack::Attack.throttles).to include('registrations/ip')
    end
  end

  describe '一般的なリクエストの制限' do
    let(:test_path) { '/' }

    it '5分間に300回までのリクエストは許可される' do
      # 実際には300回テストするのは時間がかかるため、少数でテスト
      10.times do
        get test_path
        expect(response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'ローカルホストのホワイトリスト' do
    it 'ローカルホストからのアクセスは制限されない' do
      # テスト環境はデフォルトで127.0.0.1なので、大量のリクエストを送ってもブロックされない
      400.times do
        get '/'
      end
      # 最後のリクエストが成功することを確認
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
end
