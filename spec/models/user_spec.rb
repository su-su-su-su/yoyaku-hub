# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  def setup_working_hour(stylist, day: Date.current.wday, start_time: '09:00', end_time: '17:00')
    create(:working_hour,
      stylist: stylist,
      day_of_week: day,
      target_date: nil,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
  end

  let(:customer) { create(:user, role: :customer) }
  let(:stylist) { create(:user, role: :stylist) }

  let(:date) { Date.new(2025, 6, 10) }

  describe 'validations' do
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

  describe 'associations' do
    context 'when menu tests' do
      it 'has many menus' do
        expect(stylist).to respond_to(:menus)
      end

      it 'can have multiple menus' do
        create(:menu, stylist: stylist, name: 'メニュー1')
        create(:menu, stylist: stylist, name: 'メニュー2')
        expect(stylist.menus.count).to eq(2)
      end
    end

    context 'when working hour tests' do
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
        setup_working_hour(stylist, day: 7, start_time: '10:00', end_time: '15:00')
        holiday_wh = stylist.working_hours.find_by(day_of_week: 7)
        expect(holiday_wh).to be_present
        expect(holiday_wh.start_time.strftime('%H:%M')).to eq('10:00')
        expect(holiday_wh.end_time.strftime('%H:%M')).to eq('15:00')
      end
    end

    context 'when holiday tests' do
      it 'has many holidays' do
        expect(stylist).to respond_to(:holidays)
      end

      it 'can have multiple holidays' do
        create(:holiday, stylist: stylist, target_date: Time.zone.today)
        create(:holiday, stylist: stylist, target_date: 1.week.from_now.to_date)
        expect(stylist.holidays.count).to eq(2)
      end

      it 'can have day_of_week holidays' do
        create(:holiday, stylist: stylist, day_of_week: 0, target_date: nil)
        create(:holiday, stylist: stylist, day_of_week: 6, target_date: nil)
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

    context 'when reservation tests' do
      let(:menu) { create(:menu, stylist: stylist) }

      before do
        allow(HolidayJp).to receive(:holiday?).with(Date.current).and_return(false)
        stylist.holidays.where(target_date: Date.current).destroy_all
        create(:working_hour,
          stylist: stylist,
          target_date: Date.current,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))

        start_slot_index = (Time.zone.parse('09:00').hour * 2)
        end_slot_index = (Time.zone.parse('18:00').hour * 2)

        (start_slot_index...end_slot_index).each do |slot_idx|
          create(:reservation_limit,
            stylist: stylist,
            target_date: Date.current,
            time_slot: slot_idx,
            max_reservations: 1)
        end
      end

      it 'has many reservations' do
        expect(customer).to respond_to(:reservations)
      end

      it 'can have multiple reservations' do
        create(:reservation, customer: customer, stylist: stylist,
          menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '10:00')
        create(:reservation, customer: customer, stylist: stylist,
          menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '14:00')
        expect(customer.reservations.count).to eq(2)
      end

      it 'has many stylist_reservations' do
        expect(stylist).to respond_to(:stylist_reservations)
      end

      it 'can have multiple stylist_reservations' do
        create(:reservation, customer: customer, stylist: stylist,
          menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '10:00')
        create(:reservation, customer: create(:user, role: :customer), stylist: stylist,
          menu_ids: [menu.id], start_date_str: Date.current.to_s, start_time_str: '14:00')
        expect(stylist.stylist_reservations.count).to eq(2)
      end

      it 'can find reservations for a specific date' do
        today = Date.current
        tomorrow = Date.current.tomorrow

        create(:working_hour,
          stylist: stylist,
          target_date: tomorrow,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))
        allow(HolidayJp).to receive(:holiday?).with(tomorrow).and_return(false)

        stylist.holidays.where(target_date: tomorrow).destroy_all
        start_slot_index_tmr = (Time.zone.parse('09:00').hour * 2)
        end_slot_index_tmr = (Time.zone.parse('18:00').hour * 2)

        (start_slot_index_tmr...end_slot_index_tmr).each do |slot_idx|
          create(:reservation_limit,
            stylist: stylist,
            target_date: tomorrow,
            time_slot: slot_idx,
            max_reservations: 1)
        end

        create(:reservation,
          customer: customer,
          stylist: stylist,
          menu_ids: [menu.id],
          start_date_str: today.to_s,
          start_time_str: '10:00')

        create(:reservation,
          customer: customer,
          stylist: stylist,
          menu_ids: [menu.id],
          start_date_str: tomorrow.to_s,
          start_time_str: '11:00')

        expect(stylist.stylist_reservations.where(start_at: today.all_day).count).to eq(1)
        expect(stylist.stylist_reservations.where(start_at: tomorrow.all_day).count).to eq(1)
      end
    end
  end

  describe 'from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new({
        provider: 'google_oauth2',
        uid: '123456',
        info: {
          email: 'cu@example.com',
          first_name: '太郎',
          last_name: '予約'
        }
      })
    end

    context 'when the user is new (新規登録)' do
      subject(:user_from_omniauth) { described_class.from_omniauth(auth, role) }

      let(:role) { 'customer' }

      it 'returns a new user object' do
        expect(user_from_omniauth).to be_a(described_class)
        expect(user_from_omniauth).to be_new_record
      end

      it 'assigns attributes correctly' do
        aggregate_failures 'verifying user attributes' do
          expect(user_from_omniauth.provider).to eq('google_oauth2')
          expect(user_from_omniauth.uid).to eq('123456')
          expect(user_from_omniauth.email).to eq('cu@example.com')
          expect(user_from_omniauth.family_name).to eq('予約')
          expect(user_from_omniauth.given_name).to eq('太郎')
          expect(user_from_omniauth.role).to eq('customer')
          expect(user_from_omniauth.encrypted_password).to be_present
        end
      end

      it 'does not save the user to the database directly' do
        expect { user_from_omniauth }.not_to change(described_class, :count)
      end

      it 'can be saved to create a new user' do
        new_user = described_class.from_omniauth(auth, role)
        expect { new_user.save }.to change(described_class, :count).by(1)
        expect(new_user).to be_persisted
      end
    end

    context 'when the user is new (ログインフで未登録)' do
      it 'returns nil' do
        expect(described_class.from_omniauth(auth, nil)).to be_nil
      end

      it 'does not attempt to create a new user' do
        expect do
          described_class.from_omniauth(auth, nil)
        end.not_to change(described_class, :count)
      end
    end

    context 'when the user already exists' do
      subject(:user_from_omniauth) { described_class.from_omniauth(auth, role_for_new_user_attempt) }

      let!(:existing_user) do
        create(:user, provider: 'google_oauth2', uid: '123456', email: 'old@example.com', role: 'stylist',
          family_name: nil, given_name: nil)
      end
      let(:role_for_new_user_attempt) { 'customer' }

      it 'does not create a new user' do
        expect { user_from_omniauth }.not_to change(described_class, :count)
      end

      it 'returns the existing user' do
        expect(user_from_omniauth.id).to eq(existing_user.id)
      end

      it 'updates user attributes (email, and name if blank)' do
        aggregate_failures 'verifying updated attributes' do
          expect(user_from_omniauth.email).to eq('cu@example.com')
          expect(user_from_omniauth.family_name).to eq('予約')
          expect(user_from_omniauth.given_name).to eq('太郎')
        end
      end

      it 'preserves the existing role' do
        expect(user_from_omniauth.role).to eq('stylist')
      end

      it 'does not update name if already present' do
        existing_user.update!(family_name: '田中', given_name: '太郎')

        updated_user = described_class.from_omniauth(auth, role_for_new_user_attempt)
        expect(updated_user.family_name).to eq('田中')
        expect(updated_user.given_name).to eq('太郎')
      end
    end
  end

  describe 'Devise Authentication' do
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

  describe 'Session Management' do
    let(:user) { create(:customer) }

    it 'can remember login state' do
      if user.respond_to?(:remember_me)
        user.remember_me = '1'
        user.remember_me!
        expect(user.remember_created_at).not_to be_nil
      end
    end
  end

  describe 'Password Reset' do
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

  describe '#default_shift_settings_configured?' do
    context 'when both default working hours and default reservation limits exist' do
      before do
        create(:working_hour, stylist: stylist, target_date: nil, day_of_week: nil)
        create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil)
      end

      it 'returns true' do
        expect(stylist.default_shift_settings_configured?).to be true
      end
    end

    context 'when only default working hours exist' do
      before do
        create(:working_hour, stylist: stylist, target_date: nil, day_of_week: nil)
      end

      it 'returns false' do
        expect(stylist.default_shift_settings_configured?).to be false
      end
    end

    context 'when only default reservation limits exist' do
      before do
        create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil)
      end

      it 'returns false' do
        expect(stylist.default_shift_settings_configured?).to be false
      end
    end

    context 'when neither default working hours nor default reservation limits exist' do
      it 'returns false' do
        expect(stylist.default_shift_settings_configured?).to be false
      end
    end

    context 'when only specific date or day records exist (no defaults)' do
      before do
        setup_working_hour(stylist, day: 1)
        create(:reservation_limit, stylist: stylist, target_date: Date.current, time_slot: 900)
      end

      it 'returns false' do
        expect(stylist.default_shift_settings_configured?).to be false
      end
    end
  end

  describe '#registered_menus?' do
    context 'when menus are registered for the stylist' do
      before do
        create(:menu, stylist: stylist)
      end

      it 'returns true' do
        expect(stylist.registered_menus?).to be true
      end
    end

    context 'when no menus are registered for the stylist' do
      it 'returns false' do
        expect(stylist.registered_menus?).to be false
      end
    end

    context 'when only other stylists have registered menus' do
      let(:other_stylist) { create(:user, role: :stylist) }

      before do
        create(:menu, stylist: other_stylist)
      end

      it 'returns false' do
        expect(stylist.registered_menus?).to be false
      end
    end
  end

  describe '#current_month_shifts_configured?' do
    before { travel_to Date.new(2025, 5, 10) }

    let(:current_month_date) { Date.current }
    let(:prev_month_date) { Date.current.prev_month }
    let(:next_month_date) { Date.current.next_month }

    context 'when date-specific settings exist in the current month' do
      it 'returns true if a working hour exists' do
        create(:working_hour, stylist: stylist, target_date: current_month_date)
        expect(stylist.current_month_shifts_configured?).to be true
      end

      it 'returns true if a holiday exists' do
        create(:holiday, stylist: stylist, target_date: current_month_date)
        expect(stylist.current_month_shifts_configured?).to be true
      end

      it 'returns true if a reservation limit exists' do
        create(:reservation_limit, stylist: stylist, target_date: current_month_date)
        expect(stylist.current_month_shifts_configured?).to be true
      end
    end

    context 'when no date-specific settings exist in the current month' do
      it 'returns false if no records exist for the stylist' do
        expect(stylist.current_month_shifts_configured?).to be false
      end

      it 'returns false if only default settings (target_date: nil) exist' do
        create(:working_hour, stylist: stylist, target_date: nil, day_of_week: 1)
        create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil)
        expect(stylist.current_month_shifts_configured?).to be false
      end

      it 'returns false if records exist only for other months' do
        create(:working_hour, stylist: stylist, target_date: prev_month_date)
        create(:holiday, stylist: stylist, target_date: next_month_date)
        expect(stylist.current_month_shifts_configured?).to be false
      end
    end
  end

  describe '#next_month_shifts_configured?' do
    before { travel_to Date.new(2025, 5, 10) }

    let(:current_month_date) { Date.current }
    let(:next_month_date) { Date.current.next_month }
    let(:next_next_month_date) { Date.current.next_month(2) }

    context 'when date-specific settings exist in the next month' do
      it 'returns true if a working hour exists' do
        create(:working_hour, stylist: stylist, target_date: next_month_date)
        expect(stylist.next_month_shifts_configured?).to be true
      end

      it 'returns true if a holiday exists' do
        create(:holiday, stylist: stylist, target_date: next_month_date)
        expect(stylist.next_month_shifts_configured?).to be true
      end

      it 'returns true if a reservation limit exists' do
        create(:reservation_limit, stylist: stylist, target_date: next_month_date)
        expect(stylist.next_month_shifts_configured?).to be true
      end
    end

    context 'when no date-specific settings exist in the next month' do
      it 'returns false if no records exist for the stylist' do
        expect(stylist.next_month_shifts_configured?).to be false
      end

      it 'returns false if only default settings (target_date: nil) exist' do
        create(:working_hour, stylist: stylist, target_date: nil, day_of_week: 1)
        create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil)
        expect(stylist.next_month_shifts_configured?).to be false
      end

      it 'returns false if records exist only for other months' do
        create(:working_hour, stylist: stylist, target_date: current_month_date)
        create(:holiday, stylist: stylist, target_date: next_next_month_date)
        expect(stylist.next_month_shifts_configured?).to be false
      end
    end
  end

  describe '#holiday?' do
    let(:target_date) { Date.new(2025, 3, 5) }

    context 'with specific date holiday settings' do
      it 'when is_holiday is true, returns true' do
        create(:holiday, stylist: stylist, target_date: target_date, is_holiday: true)
        expect(stylist.holiday?(target_date)).to be true
      end

      it 'when is_holiday is false, returns false' do
        create(:holiday, stylist: stylist, target_date: target_date, is_holiday: false)
        expect(stylist.holiday?(target_date)).to be false
      end
    end

    context 'when no specific date setting and the date is a Japanese holiday' do
      let(:holiday_date) { Date.new(2025, 1, 1) }

      before do
        allow(HolidayJp).to receive(:holiday?).with(holiday_date).and_return(true)
      end

      it 'with holiday settings (day_of_week: 7), returns the holiday setting' do
        create(:holiday, stylist: stylist, day_of_week: 7, target_date: nil, is_holiday: true)
        expect(stylist.holiday?(holiday_date)).to be true
      end

      it 'with weekday settings but no holiday settings, returns true' do
        wday = holiday_date.wday
        create(:holiday, stylist: stylist, day_of_week: wday, target_date: nil)
        expect(stylist.holiday?(holiday_date)).to be true
      end
    end

    context 'when no specific date setting and the date is not a holiday' do
      before do
        allow(HolidayJp).to receive(:holiday?).with(target_date).and_return(false)
      end

      it 'with weekday settings, returns true' do
        wday = target_date.wday
        create(:holiday, stylist: stylist, day_of_week: wday, target_date: nil)
        expect(stylist.holiday?(target_date)).to be true
      end

      it 'without weekday settings, returns false' do
        expect(stylist.holiday?(target_date)).to be false
      end
    end
  end

  describe '#reservation_limit_for' do
    let(:stylist) { create(:user, :stylist) }
    let(:date) { Date.new(2025, 5, 28) }

    context 'when a reservation limit for the specific date exists' do
      let!(:specific_limit) do
        create(:reservation_limit, stylist: stylist, target_date: date, max_reservations: 2)
      end

      it 'returns the specific reservation limit record' do
        expect(stylist.reservation_limit_for(date)).to eq(specific_limit)
      end
    end

    context 'when no specific date limit exists, but a global limit exists' do
      let!(:global_limit) do
        create(:reservation_limit, stylist: stylist, target_date: nil, max_reservations: 2)
      end

      it 'returns a new record with attributes from the global limit' do
        result = stylist.reservation_limit_for(date)

        expect(result).to be_a(ReservationLimit)
        expect(result).to be_new_record
        expect(result.target_date).to eq(date)
        expect(result.max_reservations).to eq(global_limit.max_reservations)
      end
    end

    context 'when no specific or global limit exists' do
      it 'returns a new record with the default max_reservations of 1' do
        result = stylist.reservation_limit_for(date)

        expect(result).to be_a(ReservationLimit)
        expect(result).to be_new_record
        expect(result.target_date).to eq(date)
        expect(result.max_reservations).to eq(1)
      end
    end
  end
  describe '#working_hour_for' do
    let(:date) { Date.new(2023, 4, 1) }

    context 'when a specific working hour exists for the date' do
      let!(:specific_wh) do
        create(:working_hour,
          stylist: stylist,
          target_date: date,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('19:00'))
      end

      it 'returns the specific working hour' do
        result = stylist.working_hour_for(date)
        expect(result).to eq(specific_wh)
      end
    end

    context 'when the date is a holiday in Japan and a holiday working hour template exists' do
      let(:holiday_date) { Date.new(2023, 1, 1) }
      let!(:holiday_template_wh) do
        create(:working_hour,
          stylist: stylist,
          day_of_week: 7,
          target_date: nil,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('15:00'))
      end

      before do
        stylist.working_hours.where(target_date: holiday_date).destroy_all
        allow(HolidayJp).to receive(:holiday?).with(holiday_date).and_return(true)
      end

      it 'returns the holiday working hour template' do
        result = stylist.working_hour_for(holiday_date)

        expect(result.id).to eq(holiday_template_wh.id) if holiday_template_wh.persisted? && result.persisted?
        expect(result.start_time.strftime('%H:%M')).to eq('10:00')
        expect(result.end_time.strftime('%H:%M')).to eq('15:00')
        expect(result.day_of_week).to eq(7)
      end
    end

    context 'when a default working hour template exists for the day of week (and not a public holiday)' do
      let!(:weekday_template_wh) do
        create(:working_hour,
          stylist: stylist,
          day_of_week: date.wday,
          target_date: nil,
          start_time: Time.zone.parse('11:00'),
          end_time: Time.zone.parse('20:00'))
      end

      before do
        stylist.working_hours.where(target_date: date).destroy_all
        allow(HolidayJp).to receive(:holiday?).with(date).and_return(false)
      end

      it 'returns the default working hour template for that day of week' do
        result = stylist.working_hour_for(date)
        expect(result.id).to eq(weekday_template_wh.id) if weekday_template_wh.persisted? && result.persisted?
        expect(result.start_time.strftime('%H:%M')).to eq('11:00')
        expect(result.end_time.strftime('%H:%M')).to eq('20:00')
        expect(result.day_of_week).to eq(date.wday)
      end
    end

    context 'when no specific or template working hour exists (and not a public holiday)' do
      before do
        stylist.working_hours.destroy_all
        allow(HolidayJp).to receive(:holiday?).with(date).and_return(false)
      end

      it 'returns a new working hour instance with default times' do
        result = stylist.working_hour_for(date)
        expect(result).to be_a_new_record
        expect(result.stylist_id).to eq(stylist.id)
        expect(result.target_date).to eq(date)
        expect(result.start_time.strftime('%H:%M')).to eq(WorkingHour::DEFAULT_START_TIME)
        expect(result.end_time.strftime('%H:%M')).to eq(WorkingHour::DEFAULT_END_TIME)
      end
    end
  end

  describe '#working_hour_for_target_date' do
    let(:date) { Date.new(2024, 7, 10) }

    context 'when a working hour for the specific target_date exists for the stylist' do
      let!(:target_specific_wh) do
        create(:working_hour,
          stylist: stylist,
          target_date: date,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('19:00'))
      end
      let!(:other_date_wh) { create(:working_hour, stylist: stylist, target_date: date + 1.day) }
      let!(:template_wh) { create(:working_hour, stylist: stylist, day_of_week: date.wday, target_date: nil) }

      it 'returns the working hour for that specific date' do
        expect(stylist.working_hour_for_target_date(date)).to eq(target_specific_wh)
      end
    end

    context 'when no working hour for the specific target_date exists for the stylist' do
      let(:other_stylist) { create(:user, role: :stylist) }

      before do
        create(:working_hour, stylist: other_stylist, target_date: date)
        create(:working_hour, stylist: stylist, target_date: date + 1.day)
        create(:working_hour, stylist: stylist, day_of_week: date.wday, target_date: nil)
      end

      it 'returns nil' do
        expect(stylist.working_hour_for_target_date(date)).to be_nil
      end
    end
  end

  describe '#generate_time_options_for_date' do

    context 'when a working hour exists for the date' do
      before do
        create(
          :working_hour,
          stylist: stylist,
          target_date: date,
          start_time: Time.zone.parse('10:00'),
          end_time: Time.zone.parse('14:00')
        )
      end

      it 'returns time options between the working hour start and end times' do
        options = stylist.generate_time_options_for_date(date)
        expect(options).to eq([
                                ['10:00', '10:00'],
                                ['10:30', '10:30'],
                                ['11:00', '11:00'],
                                ['11:30', '11:30'],
                                ['12:00', '12:00'],
                                ['12:30', '12:30'],
                                ['13:00', '13:00'],
                                ['13:30', '13:30'],
                                ['14:00', '14:00']
                              ])
      end
    end

    context 'when no working hour exists for the date' do
      before do
        allow(stylist).to receive(:working_hour_for_target_date).with(date).and_return(nil)
      end

      it 'returns time options between DEFAULT_START_TIME and DEFAULT_END_TIME' do
        options = stylist.generate_time_options_for_date(date)
        first_option = options.first
        last_option  = options.last

        expect(first_option).to eq(['09:00', '09:00'])
        expect(last_option).to eq(['18:00', '18:00'])
        expect(options.size).to eq(((18 - 9) * 2) + 1)
      end
    end
  end

  describe '#find_next_reservation_start_slot' do
    before do
      create(:working_hour,
        stylist: stylist,
        target_date: date,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('17:00'))
    end

    it 'returns the next reservation start slot from given time' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(stylist.stylist_reservations).to receive(:where)
        .with(status: %i[before_visit paid]).and_return(mock_relation)

      reservations = [
        instance_double(Reservation, start_at: Time.zone.parse("#{date} 10:00")),
        instance_double(Reservation, start_at: Time.zone.parse("#{date} 14:00"))
      ]
      allow(mock_relation).to receive(:where)
        .with(start_at: date.all_day).and_return(reservations)

      expect(stylist.find_next_reservation_start_slot(date, 18)).to eq(20)
      expect(stylist.find_next_reservation_start_slot(date, 22)).to eq(28)

      expect(stylist.find_next_reservation_start_slot(date, 30)).to eq(34)
    end

    it 'returns the end of day slot when there are no reservations' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(stylist.stylist_reservations).to receive(:where)
        .with(status: %i[before_visit paid]).and_return(mock_relation)
      allow(mock_relation).to receive(:where)
        .with(start_at: date.all_day).and_return([])

      expect(stylist.find_next_reservation_start_slot(date, 20)).to eq(34)
    end
  end

  describe '#find_previous_reservation_end_slot' do
    before do
      create(:working_hour,
        stylist: stylist,
        target_date: date,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('17:00'))
    end

    it 'returns the previous reservation end slot from given time' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(stylist.stylist_reservations).to receive(:where)
        .with(status: %i[before_visit paid]).and_return(mock_relation)

      reservations = [
        instance_double(Reservation, end_at: Time.zone.parse("#{date} 11:00")),
        instance_double(Reservation, end_at: Time.zone.parse("#{date} 15:00"))
      ]
      allow(mock_relation).to receive(:where)
        .with(start_at: date.all_day).and_return(reservations)

      expect(stylist.find_previous_reservation_end_slot(date, 24)).to eq(22)
      expect(stylist.find_previous_reservation_end_slot(date, 32)).to eq(30)
    end

    it 'returns the start of day slot when there are no reservations' do
      mock_relation = instance_double(ActiveRecord::Relation)
      allow(stylist.stylist_reservations).to receive(:where)
        .with(status: %i[before_visit paid]).and_return(mock_relation)
      allow(mock_relation).to receive(:where)
        .with(start_at: date.all_day).and_return([])

      expect(stylist.find_previous_reservation_end_slot(date, 24)).to eq(18)
    end
  end
end
