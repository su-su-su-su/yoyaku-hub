# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  let(:user) do
    create(:user, :stylist,
      email: 'test@example.com',
      password: 'correct_password',
      password_confirmation: 'correct_password')
  end

  describe 'アカウントロック機能' do
    context '連続してログインに失敗した場合' do
      it '5回失敗するとアカウントがロックされる' do
        expect(user.access_locked?).to be false

        # 5回失敗
        5.times do
          described_class.find_by(email: user.email)&.valid_for_authentication? { false }
          user.reload
        end

        expect(user.reload.access_locked?).to be true
        expect(user.failed_attempts).to eq(5)
        expect(user.locked_at).to be_present
      end

      it '4回失敗してもアカウントはロックされない' do
        4.times do
          described_class.find_by(email: user.email)&.valid_for_authentication? { false }
          user.reload
        end

        expect(user.reload.access_locked?).to be false
        expect(user.failed_attempts).to eq(4) # 4回失敗が記録される
      end
    end

    context 'アカウントがロックされた場合' do
      before do
        user.update(
          failed_attempts: 5,
          locked_at: Time.current
        )
      end

      it 'ロック状態が確認できる' do
        expect(user.access_locked?).to be true
      end

      it 'unlock_tokenが生成される' do
        user.lock_access!
        expect(user.unlock_token).to be_present
      end
    end

    context 'アカウントのロック解除' do
      before do
        user.lock_access!
      end

      it 'unlock_access!でロックが解除される' do
        expect(user.access_locked?).to be true

        user.unlock_access!

        expect(user.reload.access_locked?).to be false
        expect(user.failed_attempts).to eq(0)
        expect(user.locked_at).to be_nil
      end

      it '15分経過後は自動的にロック解除される' do
        user.update(locked_at: 16.minutes.ago)

        expect(user.access_locked?).to be false
      end

      it '15分未満ではロックが維持される' do
        user.update(locked_at: 14.minutes.ago)

        expect(user.access_locked?).to be true
      end

      it 'メールによるロック解除のためのunlock_tokenが存在する' do
        expect(user.access_locked?).to be true
        unlock_token = user.unlock_token
        expect(unlock_token).to be_present

        # unlock_tokenでユーザーを検索できることを確認（メール送信時に使用）
        found_user = described_class.find_by(unlock_token: unlock_token)
        expect(found_user).to eq(user)
        expect(found_user.access_locked?).to be true
      end

      it 'unlock_strategyが:bothに設定されている' do
        # メールでも時間経過でも解除可能な設定になっていることを確認
        expect(Devise.unlock_strategy).to eq(:both)
      end
    end
  end

  describe 'failed_attemptsのデフォルト値' do
    it '新規ユーザーのfailed_attemptsは0' do
      new_user = build(:user, :stylist)
      expect(new_user.failed_attempts).to eq(0)
    end
  end
end
