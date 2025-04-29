# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist Default Shift Settings' do
  let(:stylist) { create(:user, role: :stylist) }
  let(:settings_path) { stylists_shift_settings_path }
  let(:update_defaults_path) { update_defaults_stylists_shift_settings_path }

  before do
    sign_in stylist
  end

  describe 'Page display and access control' do
    it 'displays the default settings form correctly' do
      visit settings_path

      expect(page).to have_content('シフト設定')
      expect(page).to have_content('営業時間')
      expect(page).to have_content('休業日')
      expect(page).to have_content('受付可能数')

      form = find("form[action='#{update_defaults_path}'][method='post']")
      expect(form).to be_present

      expect(form).to have_field('default_settings[working_hour][weekday_start_time]')
      within('#default_holiday_settings') do
        expect(form).to have_field('default_settings[holiday][day_of_weeks][]', type: 'checkbox', count: 8)
        expect(form).to have_field('default_settings[holiday][day_of_weeks][]', type: 'hidden', visible: :hidden)
        expect(page).to have_field('月曜日')
        expect(page).to have_field('祝祭日')
      end
      expect(form).to have_select('default_settings[reservation_limit][max_reservations]')

      expect(form).to have_button('勤務のデフォルトを保存')
      expect(form).to have_no_button('設定')
    end

    it 'prevents non-stylist users from accessing the settings page' do
      customer = create(:user, role: :customer)
      sign_out stylist
      sign_in customer
      visit settings_path
      expect(page).to have_no_current_path(settings_path, ignore_query: true)
    end
  end

  describe 'Setting and updating default settings' do
    it 'can set new default settings for all items' do
      visit settings_path

      select '10:00', from: 'default_settings[working_hour][weekday_start_time]'
      select '19:00', from: 'default_settings[working_hour][weekday_end_time]'
      select '11:00', from: 'default_settings[working_hour][saturday_start_time]'
      select '18:00', from: 'default_settings[working_hour][saturday_end_time]'
      select '12:00', from: 'default_settings[working_hour][sunday_start_time]'
      select '17:00', from: 'default_settings[working_hour][sunday_end_time]'
      select '10:30', from: 'default_settings[working_hour][holiday_start_time]'
      select '16:30', from: 'default_settings[working_hour][holiday_end_time]'

      within('#default_holiday_settings') do
        check '月曜日'
        check '金曜日'
      end

      select '2', from: 'default_settings[reservation_limit][max_reservations]'

      click_on '勤務のデフォルトを保存'

      expect(page).to have_content(I18n.t('stylists.shift_settings.defaults.update_success'))

      (1..5).each do |wday|
        wh = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: wday, target_date: nil)
        expect(wh.start_time.strftime('%H:%M')).to eq '10:00'
        expect(wh.end_time.strftime('%H:%M')).to eq '19:00'
      end
      wh_sat = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 6, target_date: nil)
      expect(wh_sat.start_time.strftime('%H:%M')).to eq '11:00'
      expect(wh_sat.end_time.strftime('%H:%M')).to eq '18:00'
      wh_sun = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 0, target_date: nil)
      expect(wh_sun.start_time.strftime('%H:%M')).to eq '12:00'
      expect(wh_sun.end_time.strftime('%H:%M')).to eq '17:00'
      wh_hol = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 7, target_date: nil)
      expect(wh_hol.start_time.strftime('%H:%M')).to eq '10:30'
      expect(wh_hol.end_time.strftime('%H:%M')).to eq '16:30'

      expect(Holiday.where(stylist_id: stylist.id,
        target_date: nil).where.not(day_of_week: nil).pluck(:day_of_week)).to contain_exactly(1, 5)

      limit = ReservationLimit.find_by!(stylist_id: stylist.id, target_date: nil, time_slot: nil)
      expect(limit.max_reservations).to eq 2

      visit settings_path
      expect(page).to have_select('default_settings[working_hour][weekday_start_time]', selected: '10:00')
      within('#default_holiday_settings') do
        expect(find_field('月曜日')).to be_checked
        expect(find_field('金曜日')).to be_checked
        expect(find_field('火曜日')).not_to be_checked
      end
      expect(page).to have_select('default_settings[reservation_limit][max_reservations]', selected: '2')
    end

    it 'can update existing default settings for all items' do
      (1..5).each do |wd|
        create(:working_hour, stylist: stylist, day_of_week: wd, target_date: nil, start_time: Time.zone.parse('08:00'))
      end
      create(:working_hour, stylist: stylist, day_of_week: 6, target_date: nil, start_time: Time.zone.parse('09:00'))
      create(:working_hour, stylist: stylist, day_of_week: 0, target_date: nil, start_time: Time.zone.parse('09:00'))
      create(:working_hour, stylist: stylist, day_of_week: 7, target_date: nil, start_time: Time.zone.parse('09:00'))

      create(:holiday, stylist: stylist, day_of_week: 1, target_date: nil)
      create(:holiday, stylist: stylist, day_of_week: 5, target_date: nil)
      create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil, max_reservations: 1)

      visit settings_path

      expect(page).to have_select('default_settings[working_hour][weekday_start_time]', selected: '08:00')
      within('#default_holiday_settings') do
        expect(find_field('月曜日')).to be_checked
        expect(find_field('金曜日')).to be_checked
        expect(find_field('日曜日')).not_to be_checked
      end
      expect(page).to have_select('default_settings[reservation_limit][max_reservations]', selected: '1')

      select '11:00', from: 'default_settings[working_hour][weekday_start_time]'
      select '20:00', from: 'default_settings[working_hour][weekday_end_time]'
      select '12:00', from: 'default_settings[working_hour][saturday_start_time]'
      select '19:00', from: 'default_settings[working_hour][saturday_end_time]'
      select '13:00', from: 'default_settings[working_hour][sunday_start_time]'
      select '18:00', from: 'default_settings[working_hour][sunday_end_time]'
      select '10:00', from: 'default_settings[working_hour][holiday_start_time]'
      select '16:00', from: 'default_settings[working_hour][holiday_end_time]'

      within('#default_holiday_settings') do
        uncheck '月曜日'
        check '日曜日'
      end

      select '0', from: 'default_settings[reservation_limit][max_reservations]'

      click_on '勤務のデフォルトを保存'

      expect(page).to have_content(I18n.t('stylists.shift_settings.defaults.update_success'))

      (1..5).each do |wday|
        wh = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: wday, target_date: nil)
        expect(wh.start_time.strftime('%H:%M')).to eq '11:00'
        expect(wh.end_time.strftime('%H:%M')).to eq '20:00'
      end
      wh_sat = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 6, target_date: nil)
      expect(wh_sat.start_time.strftime('%H:%M')).to eq '12:00'
      expect(wh_sat.end_time.strftime('%H:%M')).to eq '19:00'
      wh_sun = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 0, target_date: nil)
      expect(wh_sun.start_time.strftime('%H:%M')).to eq '13:00'
      expect(wh_sun.end_time.strftime('%H:%M')).to eq '18:00'
      wh_hol = WorkingHour.find_by!(stylist_id: stylist.id, day_of_week: 7, target_date: nil)
      expect(wh_hol.start_time.strftime('%H:%M')).to eq '10:00'
      expect(wh_hol.end_time.strftime('%H:%M')).to eq '16:00'

      expect(Holiday.where(stylist_id: stylist.id, target_date: nil).where.not(day_of_week: nil).pluck(:day_of_week)).to contain_exactly(0, 5)

      limit = ReservationLimit.find_by!(stylist_id: stylist.id, target_date: nil, time_slot: nil)
      expect(limit.max_reservations).to eq 0

      visit settings_path
      expect(page).to have_select('default_settings[working_hour][weekday_start_time]', selected: '11:00')
      within('#default_holiday_settings') do
        expect(find_field('月曜日')).not_to be_checked
        expect(find_field('日曜日')).to be_checked
        expect(find_field('金曜日')).to be_checked
      end
      expect(page).to have_select('default_settings[reservation_limit][max_reservations]', selected: '0')
    end

    it 'can remove all holidays while setting other defaults' do
      create(:holiday, stylist: stylist, day_of_week: 0, target_date: nil)
      create(:holiday, stylist: stylist, day_of_week: 6, target_date: nil)
      (1..5).each { |wd| create(:working_hour, stylist: stylist, day_of_week: wd, target_date: nil) }
      create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil, max_reservations: 1)

      visit settings_path

      within('#default_holiday_settings') do
        expect(find_field('日曜日')).to be_checked
        expect(find_field('土曜日')).to be_checked
      end

      within('#default_holiday_settings') do
        weekdays = { 1 => '月曜日', 2 => '火曜日', 3 => '水曜日', 4 => '木曜日', 5 => '金曜日', 6 => '土曜日', 0 => '日曜日', 7 => '祝祭日' }
        weekdays.each_value do |label_text|
          checkbox = find_field(label_text, type: 'checkbox', visible: true)
          uncheck(label_text) if checkbox.checked?
        end
      end

      select '09:00', from: 'default_settings[working_hour][weekday_start_time]'
      select '18:00', from: 'default_settings[working_hour][weekday_end_time]'
      select '11:00', from: 'default_settings[working_hour][saturday_start_time]'
      select '18:00', from: 'default_settings[working_hour][saturday_end_time]'
      select '12:00', from: 'default_settings[working_hour][sunday_start_time]'
      select '17:00', from: 'default_settings[working_hour][sunday_end_time]'
      select '09:30', from: 'default_settings[working_hour][holiday_start_time]'
      select '16:30', from: 'default_settings[working_hour][holiday_end_time]'
      select '1', from: 'default_settings[reservation_limit][max_reservations]'

      click_on '勤務のデフォルトを保存'

      expect(page).to have_content(I18n.t('stylists.shift_settings.defaults.update_success'))

      expect(Holiday.where(stylist_id: stylist.id, target_date: nil).where.not(day_of_week: nil)).to be_empty

      limit = ReservationLimit.find_by!(stylist_id: stylist.id, target_date: nil, time_slot: nil)
      expect(limit.max_reservations).to eq 1

      visit settings_path
      within('#default_holiday_settings') do

        weekdays = { 1 => '月曜日', 2 => '火曜日', 3 => '水曜日', 4 => '木曜日', 5 => '金曜日', 6 => '土曜日', 0 => '日曜日', 7 => '祝祭日' }
        weekdays.each_value do |label_text|
          expect(find_field(label_text, type: 'checkbox', visible: true)).not_to be_checked
        end
      end
      expect(page).to have_select('default_settings[reservation_limit][max_reservations]', selected: '1')

    it 'can set national holidays as a holiday while setting other defaults' do
      Holiday.where(stylist_id: stylist.id, day_of_week: 7, target_date: nil).destroy_all
      (0..7).each do |wd|
        create(:working_hour, stylist: stylist, day_of_week: wd, target_date: nil) unless WorkingHour.exists?(
          stylist_id: stylist.id, day_of_week: wd, target_date: nil
        )
      end
      create(:reservation_limit, stylist: stylist, target_date: nil, time_slot: nil,
        max_reservations: 1) unless ReservationLimit.exists?(
          stylist_id: stylist.id, target_date: nil, time_slot: nil
        )

      visit settings_path

      within('#default_holiday_settings') do
        expect(find_field('祝祭日')).not_to be_checked
      end

      within('#default_holiday_settings') do
        check '祝祭日'
      end

      select '09:00', from: 'default_settings[working_hour][weekday_start_time]'
      select '18:00', from: 'default_settings[working_hour][weekday_end_time]'
      select '11:00', from: 'default_settings[working_hour][saturday_start_time]'
      select '18:00', from: 'default_settings[working_hour][saturday_end_time]'
      select '12:00', from: 'default_settings[working_hour][sunday_start_time]'
      select '17:00', from: 'default_settings[working_hour][sunday_end_time]'
      select '09:30', from: 'default_settings[working_hour][holiday_start_time]'
      select '16:30', from: 'default_settings[working_hour][holiday_end_time]'
      select '2', from: 'default_settings[reservation_limit][max_reservations]'

      click_on '勤務のデフォルトを保存'

      expect(page).to have_content(I18n.t('stylists.shift_settings.defaults.update_success'))

      expect(Holiday.where(stylist_id: stylist.id,
        target_date: nil).where.not(day_of_week: nil).pluck(:day_of_week)).to contain_exactly(7)

      expect(Holiday).to exist(stylist_id: stylist.id, day_of_week: 7, target_date: nil)

      limit = ReservationLimit.find_by!(stylist_id: stylist.id, target_date: nil, time_slot: nil)
      expect(limit.max_reservations).to eq 2

      visit settings_path
      within('#default_holiday_settings') do
        expect(find_field('祝祭日')).to be_checked
      end
      expect(page).to have_select('default_settings[reservation_limit][max_reservations]', selected: '2')
    end
  end
end
