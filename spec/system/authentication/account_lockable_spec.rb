# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account Lockable System Test' do
  let!(:stylist) do
    create(:user, :stylist,
      email: 'stylist@example.com',
      password: 'correct_password',
      password_confirmation: 'correct_password')
  end

  before do
    driven_by(:rack_test)
  end

  describe 'ログイン失敗によるアカウントロック' do
    it '5回ログインに失敗するとアカウントがロックされる' do
      visit new_user_session_path

      # 4回失敗
      4.times do
        fill_in 'user_email', with: stylist.email
        fill_in 'user_password', with: 'wrong_password'
        click_button 'ログイン'

        # ログインページに留まる
        expect(page).to have_current_path('/login', url: false)
      end

      # 5回目の失敗でロックされる
      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'wrong_password'
      click_button 'ログイン'

      # ログインページに留まる（アカウントロック）
      expect(page).to have_current_path('/login', url: false)

      # データベースで確認
      stylist.reload
      expect(stylist.access_locked?).to be true
      expect(stylist.failed_attempts).to eq(5)
    end

    it 'アカウントがロックされると正しいパスワードでもログインできない' do
      # アカウントを事前にロック
      stylist.lock_access!

      visit new_user_session_path

      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'correct_password'
      click_button 'ログイン'

      # ロックされているためログインできない（ログインページに留まる）
      expect(page).to have_current_path('/login', url: false)
      expect(page).to have_no_content('予約表')
    end
  end

  describe '時間経過によるロック解除' do
    it '15分経過後は自動的にロック解除され、ログインできる' do
      # アカウントをロックし、16分前にロックされたことにする
      stylist.lock_access!
      stylist.update(locked_at: 16.minutes.ago)

      visit new_user_session_path

      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'correct_password'
      click_button 'ログイン'

      # ログイン成功（ダッシュボードに遷移）
      expect(page).to have_current_path('/stylists/dashboard', url: false)
      expect(page).to have_content('予約表')

      # データベースでロック解除を確認
      stylist.reload
      expect(stylist.access_locked?).to be false
    end

    it '15分未満ではロックが維持され、ログインできない' do
      # アカウントをロックし、14分前にロックされたことにする
      stylist.lock_access!
      stylist.update(locked_at: 14.minutes.ago)

      visit new_user_session_path

      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'correct_password'
      click_button 'ログイン'

      # まだロックされているためログインできない（ログインページに留まる）
      expect(page).to have_current_path('/login', url: false)
      expect(page).to have_no_content('予約表')

      # データベースでロック状態を確認
      stylist.reload
      expect(stylist.access_locked?).to be true
    end
  end

  describe 'メールによるロック解除' do
    it 'unlock_tokenを使ってロック解除できる' do
      # アカウントをロック（send_unlock_instructionsでトークンを生成）
      raw_token, encrypted_token = Devise.token_generator.generate(User, :unlock_token)
      stylist.update(
        locked_at: Time.current,
        unlock_token: encrypted_token
      )

      # ロック解除用のURL（生の未暗号化トークンを使用）を訪問
      visit "/users/unlock?unlock_token=#{raw_token}"

      # データベースでロック解除を確認
      stylist.reload
      expect(stylist.access_locked?).to be false
      expect(stylist.unlock_token).to be_nil

      # ログインできることを確認
      visit new_user_session_path
      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'correct_password'
      click_button 'ログイン'

      expect(page).to have_current_path('/stylists/dashboard', url: false)
      expect(page).to have_content('予約表')
    end

    it '無効なunlock_tokenではロック解除できない' do
      # アカウントをロック
      stylist.lock_access!

      # 無効なトークンでロック解除を試みる
      visit '/users/unlock?unlock_token=invalid_token'

      # エラーメッセージが表示される
      expect(page).to have_content('ロック解除用トークンは不正な値です')

      # データベースで確認（まだロックされている）
      stylist.reload
      expect(stylist.access_locked?).to be true
    end
  end

  describe 'ロック後のログイン成功でfailed_attemptsがリセットされる' do
    it 'ロック解除後、正しいパスワードでログインするとfailed_attemptsが0になる' do
      # 3回失敗させる
      visit new_user_session_path

      3.times do
        fill_in 'user_email', with: stylist.email
        fill_in 'user_password', with: 'wrong_password'
        click_button 'ログイン'
      end

      stylist.reload
      expect(stylist.failed_attempts).to eq(3)

      # 正しいパスワードでログイン成功
      fill_in 'user_email', with: stylist.email
      fill_in 'user_password', with: 'correct_password'
      click_button 'ログイン'

      expect(page).to have_content('予約表')

      # failed_attemptsがリセットされる
      stylist.reload
      expect(stylist.failed_attempts).to eq(0)
    end
  end
end
