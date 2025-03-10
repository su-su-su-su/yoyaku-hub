# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  describe 'バリデーション' do
    context 'when it has basic validations' do
      it 'is valid with valid attributes' do
        user = build(:customer)
        expect(user).to be_valid
      end

      it 'is invalid without an email' do
        user = build(:customer, email: nil)
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include(I18n.t('errors.messages.blank'))
      end

      it 'is invalid with duplicate email' do
        create(:customer, email: 'duplicate@example.com')
        user = build(:customer, email: 'duplicate@example.com')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include(I18n.t('errors.messages.taken'))
      end

      it 'is valid with katakana in name_kana fields' do
        user = build(:user, :with_kana)
        expect(user).to be_valid
      end

      it 'is invalid with non-katakana in family_name_kana' do
        user = build(:user, family_name_kana: 'biyoshi')
        expect(user).not_to be_valid
        expect(user.errors[:family_name_kana]).to include(I18n.t('errors.messages.only_katakana'))
      end

      it 'is invalid with non-katakana in given_name_kana' do
        user = build(:user, given_name_kana: 'taro')
        expect(user).not_to be_valid
        expect(user.errors[:given_name_kana]).to include(I18n.t('errors.messages.only_katakana'))
      end

      it 'allows blank values for kana fields' do
        user = build(:user, family_name_kana: '', given_name_kana: '')
        expect(user).to be_valid
      end
    end

    context 'when validating passwords' do
      it 'is invalid with too short password' do
        user = build(:customer, password: 'test', password_confirmation: '12345')
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include(I18n.t('errors.messages.too_short', count: 6))
      end

      it 'is invalid with password confirmation mismatch' do
        user = build(:customer, password: 'password', password_confirmation: 'pass')
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include(
          I18n.t('errors.messages.confirmation',
                 attribute: described_class.human_attribute_name(:password))
        )
      end
    end
  end

  describe 'アソシエーション' do
    let(:stylist) { create(:user, :stylist) }

    it 'has many menus' do
      expect(stylist).to respond_to(:menus)
    end

    it 'can have multiple menus' do
      create(:menu, stylist: stylist, name: 'メニュー1')
      create(:menu, stylist: stylist, name: 'メニュー2')
      expect(stylist.menus.count).to eq(2)
    end

    it 'has many working_hours' do
      expect(stylist).to respond_to(:working_hours)
    end

    it 'can have multiple working_hours' do
      create(:working_hour, stylist: stylist, target_date: Time.zone.today)
      create(:working_hour, stylist: stylist, target_date: Date.tomorrow)
      expect(stylist.working_hours.count).to eq(2)
    end

    it 'can have day_of_week working hours' do
      create(:working_hour, stylist: stylist, day_of_week: 1, target_date: nil)
      create(:working_hour, stylist: stylist, day_of_week: 6, target_date: nil)
      expect(stylist.working_hours.where(target_date: nil).count).to eq(2)
    end

    it 'can have holiday working hours' do
      create(:working_hour,
             stylist: stylist,
             day_of_week: 7,
             target_date: nil,
             start_time: Time.zone.parse('10:00'),
             end_time: Time.zone.parse('15:00'))

      holiday_wh = stylist.working_hours.find_by(day_of_week: 7)
      expect(holiday_wh).to be_present
      expect(holiday_wh.start_time.strftime('%H:%M')).to eq('10:00')
      expect(holiday_wh.end_time.strftime('%H:%M')).to eq('15:00')
    end

    it 'has many holidays' do
      expect(stylist).to respond_to(:holidays)
    end

    it 'can have multiple holidays' do
      create(:holiday, stylist: stylist, target_date: Time.zone.today)
      create(:holiday, stylist: stylist, target_date: 1.week.from_now.to_date)
      expect(stylist.holidays.count).to eq(2)
    end

    it 'can have day_of_week holidays' do
      create(:holiday, stylist: stylist, day_of_week: 0, target_date: nil)  # 日曜日
      create(:holiday, stylist: stylist, day_of_week: 6, target_date: nil)  # 土曜日
      expect(stylist.holidays.where(target_date: nil).count).to eq(2)
    end

    it 'can have holiday settings for Japanese holidays' do
      create(:holiday,
             stylist: stylist,
             day_of_week: 7,
             target_date: nil,
             is_holiday: true)

      jp_holiday = stylist.holidays.find_by(day_of_week: 7)
      expect(jp_holiday).to be_present
      expect(jp_holiday.is_holiday).to be true
    end
  end

  describe 'OAuthログイン (.from_omniauth)' do
    let(:auth) do
      OmniAuth::AuthHash.new({
                               provider: 'google_oauth2',
                               uid: '123456',
                               info: {
                                 email: 'ca@example.com',
                                 first_name: '太郎',
                                 last_name: '予約'
                               }
                             })
    end

    context 'when the user is new' do
      it 'creates a new user' do
        expect do
          described_class.from_omniauth(auth, 'customer')
        end.to change(described_class, :count).by(1)
      end

      it 'sets user attributes correctly' do
        user = described_class.from_omniauth(auth, 'customer')

        aggregate_failures 'verifying user attributes' do
          expect(user.provider).to eq('google_oauth2')
          expect(user.uid).to eq('123456')
          expect(user.email).to eq('ca@example.com')
          expect(user.family_name).to eq('予約')
          expect(user.given_name).to eq('太郎')
          expect(user.role).to eq('customer')
        end
      end
    end

    context 'when the user already exists' do
      let!(:existing_user) do
        create(:user, :with_oauth, provider: 'google_oauth2', uid: '123456', email: 'old@example.com')
      end

      it 'does not create a new user' do
        expect do
          described_class.from_omniauth(auth, 'customer')
        end.not_to change(described_class, :count)
      end

      it 'updates user attributes' do
        user = described_class.from_omniauth(auth, 'customer')

        aggregate_failures 'verifying updated attributes' do
          expect(user.id).to eq(existing_user.id)
          expect(user.email).to eq('ca@example.com')
        end
      end

      it 'preserves the existing role' do
        existing_user.update(role: 'stylist')
        user = described_class.from_omniauth(auth, 'customer')

        expect(user.role).to eq('stylist')
      end
    end
  end

  describe 'Devise認証' do
    context 'when using basic authentication' do
      let(:user) { create(:customer, password: 'testtest', password_confirmation: 'testtest') }

      it 'valid_password?メソッドで正しいパスワードを検証できる' do
        expect(user).to be_valid_password('testtest') if user.respond_to?(:valid_password?)
      end

      it 'valid_password?メソッドで間違ったパスワードを拒否できる' do
        expect(user).not_to be_valid_password('testtes') if user.respond_to?(:valid_password?)
      end
    end
  end

  describe 'セッション管理' do
    let(:user) { create(:customer) }

    it 'can remember login state' do
      if user.respond_to?(:remember_me)
        user.remember_me = '1'
        user.remember_me!
        expect(user.remember_created_at).not_to be_nil
      end
    end
  end

  describe 'パスワードリセット' do
    let(:user) { create(:customer) }

    it 'can send reset password instructions' do
      if user.respond_to?(:send_reset_password_instructions)
        expect { user.send_reset_password_instructions }.to change(user, :reset_password_token).from(nil)
      end
    end

    it 'can check if reset token is expired' do
      if user.respond_to?(:reset_password_period_valid?)
        user.send_reset_password_instructions if user.respond_to?(:send_reset_password_instructions)
        expect(user).to be_reset_password_period_valid

        if user.respond_to?(:reset_password_sent_at)
          user.reset_password_sent_at = 3.days.ago
          expect(user).not_to be_reset_password_period_valid
        end
      end
    end
  end

  describe '#min_active_menu_duration' do
    let(:stylist) { create(:user, :stylist) }

    context 'when stylist has no menus' do
      it 'returns 0' do
        expect(stylist.min_active_menu_duration).to eq(0)
      end
    end

    context 'when stylist has active menus' do
      before do
        create(:menu, stylist: stylist, name: 'メニュー1', duration: 60, is_active: true)
        create(:menu, stylist: stylist, name: 'メニュー2', duration: 30, is_active: true)
        create(:menu, stylist: stylist, name: 'メニュー3', duration: 90, is_active: false)
      end

      it 'returns the minimum duration of active menus' do
        expect(stylist.min_active_menu_duration).to eq(30)
      end
    end

    context 'when stylist has only inactive menus' do
      before do
        create(:menu, stylist: stylist, name: '非アクティブメニュー', duration: 90, is_active: false)
      end

      it 'returns 0' do
        expect(stylist.min_active_menu_duration).to eq(0)
      end
    end
  end
end
