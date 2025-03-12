# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylist shift settings' do
  let(:stylist) { create(:user, role: :stylist) }

  describe 'Main settings page' do
    before do
      sign_in stylist
      visit stylists_shift_settings_path
    end

    it 'displays the shift settings page with all sections' do
      expect(page).to have_content('シフト設定')

      expect(page).to have_content('営業時間')
      expect(page).to have_css('form[action$="/stylists/shift_settings/working_hours"]')

      expect(page).to have_content('休業日')
      expect(page).to have_css('form[action$="/stylists/shift_settings/holidays"]')

      expect(page).to have_content('受付可能数')
      expect(page).to have_css('form[action$="/stylists/shift_settings/reservation_limits"]')

      expect(page).to have_content('毎月の受付設定')

      expect(page).to have_css('.card-body p.text-lg.font-bold', count: 3)
    end

    it 'displays monthly settings cards with correct labels' do
      today = Time.zone.today
      this_month = today.month
      next_month = today.next_month.month
      next_next_month = today.next_month.next_month.month

      expect(page).to have_content(today.year.to_s)
      expect(page).to have_content("#{this_month}月")

      expect(page).to have_content(today.next_month.year.to_s)
      expect(page).to have_content("#{next_month}月")

      expect(page).to have_content(today.next_month.next_month.year.to_s)
      expect(page).to have_content("#{next_next_month}月")

      expect(page).to have_content('未設定')
    end

    it 'navigates to monthly settings page when clicking on a month card' do
      today = Time.zone.today
      this_month_year = today.year
      this_month = today.month

      find(".card a[href*='#{this_month_year}/#{this_month}']").click

      expect(page).to have_content("#{this_month_year}年#{this_month}月の受付設定")
      expect(page).to have_css('table.table')
    end
  end

  describe 'Monthly settings page' do
    let(:year) { Time.zone.today.year }
    let(:month) { Time.zone.today.month }

    before do
      sign_in stylist
      visit show_stylists_shift_settings_path(year: year, month: month)
    end

    it 'displays calendar with days of the month' do
      expect(page).to have_content("#{year}年#{month}月の受付設定")
      expect(page).to have_css('table.table')

      expect(page).to have_css('th', count: 7)

      days_in_month = Date.new(year, month, -1).day
      expect(page).to have_css('.day-cell', minimum: days_in_month)
    end

    it 'allows toggling holiday status for a day' do
      first_day_cell = find('.day-cell', match: :first)

      within(first_day_cell) do
        check '休業日'

        expect(page).to have_field('休業日', checked: true)
      end
    end

    it 'submits normal working hours and holiday settings and shows as configured on index page' do
      normal_day = 1
      holiday_day = 5

      WorkingHour.where(stylist_id: stylist.id).count
      Holiday.where(stylist_id: stylist.id).count

      expect(page).to have_css('form table')
      expect(page).to have_button('一括設定')

      normal_day_field = find("input[name='shift_data[#{normal_day}][date]']", visible: :hidden)
      normal_day_cell = normal_day_field.ancestor('.day-cell')

      within(normal_day_cell) do
        select '14:00', from: "shift_data[#{normal_day}][start_time]"
        select '22:00', from: "shift_data[#{normal_day}][end_time]"
        select '2', from: "shift_data[#{normal_day}][max_reservations]"

        expect(page).to have_field("shift_data[#{normal_day}][is_holiday]", checked: false)
      end

      holiday_day_field = find("input[name='shift_data[#{holiday_day}][date]']", visible: :hidden)
      holiday_day_cell = holiday_day_field.ancestor('.day-cell')

      within(holiday_day_cell) do
        check "shift_data[#{holiday_day}][is_holiday]"

        expect(page).to have_field("shift_data[#{holiday_day}][is_holiday]", checked: true)
      end

      click_on '一括設定'

      sleep(1) if Capybara.current_driver == :selenium_chrome_headless

      normal_date = Date.new(year, month, normal_day)
      normal_wh = WorkingHour.find_by(stylist_id: stylist.id, target_date: normal_date)

      expect(normal_wh).to be_present
      expect(normal_wh.start_time.strftime('%H:%M')).to eq '14:00'
      expect(normal_wh.end_time.strftime('%H:%M')).to eq '22:00'

      normal_holiday = Holiday.find_by(stylist_id: stylist.id, target_date: normal_date, is_holiday: true)
      expect(normal_holiday).to be_nil

      holiday_date = Date.new(year, month, holiday_day)

      holiday = Holiday.find_by(stylist_id: stylist.id, target_date: holiday_date)
      expect(holiday).to be_present
      expect(holiday.is_holiday).to be true

      WorkingHour.find_by(stylist_id: stylist.id, target_date: holiday_date)

      visit stylists_shift_settings_path

      month_card = find('.card', text: "#{year}\n#{month}月")
      expect(month_card).to have_content('設定済み')

      expect(month_card).to have_no_content('未設定')
    end
  end

  describe 'Access restrictions' do
    it 'restricts access for non-stylist users' do
      customer = create(:user, role: :customer)
      sign_in customer

      visit stylists_shift_settings_path

      expect(page).to have_no_current_path(stylists_shift_settings_path)
    end

    it 'requires authentication' do
      visit stylists_shift_settings_path

      expect(page).to have_no_content('シフト設定')
      expect(page).to have_current_path(%r{\A/(login)?\z})
    end
  end
end
