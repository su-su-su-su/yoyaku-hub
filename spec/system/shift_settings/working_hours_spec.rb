# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist working hours settings' do
  let(:stylist) { create(:user, role: :stylist) }

  describe 'Working hours configuration' do
    before do
      sign_in stylist
      visit stylists_shift_settings_path
    end

    it 'can access the working hours settings page' do
      expect(page).to have_current_path(stylists_shift_settings_path)
      expect(page).to have_content('営業時間')
      expect(page).to have_css('form[action="/stylists/shift_settings/working_hours"]')
    end

    it 'can set new working hours' do
      select '10:00', from: 'working_hour[weekday_start_time]'
      select '19:00', from: 'working_hour[weekday_end_time]'

      select '11:00', from: 'working_hour[saturday_start_time]'
      select '18:00', from: 'working_hour[saturday_end_time]'

      select '12:00', from: 'working_hour[sunday_start_time]'
      select '17:00', from: 'working_hour[sunday_end_time]'

      select '10:30', from: 'working_hour[holiday_start_time]'
      select '16:30', from: 'working_hour[holiday_end_time]'

      within('form[action="/stylists/shift_settings/working_hours"]') do
        click_on '設定'
      end

      expect(page).to have_content(I18n.t('stylists.shift_settings.working_hours.create_success'))

      (1..5).each do |wday|
        wh = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: wday)
        expect(wh).to be_present
        expect(wh.start_time.strftime('%H:%M')).to eq '10:00'
        expect(wh.end_time.strftime('%H:%M')).to eq '19:00'
      end

      wh_sat = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 6)
      expect(wh_sat).to be_present
      expect(wh_sat.start_time.strftime('%H:%M')).to eq '11:00'
      expect(wh_sat.end_time.strftime('%H:%M')).to eq '18:00'

      wh_sun = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 0)
      expect(wh_sun).to be_present
      expect(wh_sun.start_time.strftime('%H:%M')).to eq '12:00'
      expect(wh_sun.end_time.strftime('%H:%M')).to eq '17:00'

      wh_holiday = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 7)
      expect(wh_holiday).to be_present
      expect(wh_holiday.start_time.strftime('%H:%M')).to eq '10:30'
      expect(wh_holiday.end_time.strftime('%H:%M')).to eq '16:30'
    end

    it 'can update existing working hours' do
      (1..5).each do |wday|
        create(:working_hour, stylist: stylist, day_of_week: wday,
                              start_time: Time.zone.parse('08:00'), end_time: Time.zone.parse('17:00'))
      end
      create(:working_hour, stylist: stylist, day_of_week: 6,
                            start_time: Time.zone.parse('09:00'), end_time: Time.zone.parse('16:00'))
      create(:working_hour, stylist: stylist, day_of_week: 0,
                            start_time: Time.zone.parse('10:00'), end_time: Time.zone.parse('15:00'))
      create(:working_hour, stylist: stylist, day_of_week: 7,
                            start_time: Time.zone.parse('09:30'), end_time: Time.zone.parse('14:30'))

      visit stylists_shift_settings_path

      select '11:00', from: 'working_hour[weekday_start_time]'
      select '20:00', from: 'working_hour[weekday_end_time]'

      select '12:00', from: 'working_hour[saturday_start_time]'
      select '19:00', from: 'working_hour[saturday_end_time]'

      select '13:00', from: 'working_hour[sunday_start_time]'
      select '18:00', from: 'working_hour[sunday_end_time]'

      select '11:30', from: 'working_hour[holiday_start_time]'
      select '17:30', from: 'working_hour[holiday_end_time]'

      within('form[action="/stylists/shift_settings/working_hours"]') do
        click_on '設定'
      end

      expect(page).to have_content(I18n.t('stylists.shift_settings.working_hours.create_success'))

      (1..5).each do |wday|
        wh = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: wday)
        expect(wh).to be_present
        expect(wh.start_time.strftime('%H:%M')).to eq '11:00'
        expect(wh.end_time.strftime('%H:%M')).to eq '20:00'
      end

      wh_sat = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 6)
      expect(wh_sat).to be_present
      expect(wh_sat.start_time.strftime('%H:%M')).to eq '12:00'
      expect(wh_sat.end_time.strftime('%H:%M')).to eq '19:00'

      wh_sun = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 0)
      expect(wh_sun).to be_present
      expect(wh_sun.start_time.strftime('%H:%M')).to eq '13:00'
      expect(wh_sun.end_time.strftime('%H:%M')).to eq '18:00'

      wh_holiday = WorkingHour.find_by(stylist_id: stylist.id, day_of_week: 7)
      expect(wh_holiday).to be_present
      expect(wh_holiday.start_time.strftime('%H:%M')).to eq '11:30'
      expect(wh_holiday.end_time.strftime('%H:%M')).to eq '17:30'
    end
  end

  describe 'Access restrictions' do
    it 'non-stylist users cannot access the settings page' do
      customer = create(:user, role: :customer)
      sign_in customer

      visit stylists_shift_settings_path

      expect(page).to have_no_current_path stylists_shift_settings_path, ignore_query: true
    end
  end
end
