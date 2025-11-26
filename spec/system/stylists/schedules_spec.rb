# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylists::Schedules' do
  let(:stylist) { create(:user, role: :stylist) }
  let(:customer) { create(:user, role: :customer) }
  let(:today) { Date.current }

  def to_slot_index(time_str)
    h, m = time_str.split(':').map(&:to_i)
    (h * 2) + (m >= 30 ? 1 : 0)
  end

  describe 'Reservation Schedule Screen' do
    context 'when logged in as a stylist' do
      before do
        sign_in stylist
        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
      end

      it 'displays date and date navigation buttons' do
        expect(page).to have_content(I18n.l(today, format: :long))
        expect(page).to have_content('前の日')
        expect(page).to have_content('後の日')
      end

      it 'displays message when business hours are not set' do
        expect(page).to have_content('営業時間未設定')
      end
    end
  end

  describe 'With Business Hours' do
    let(:working_hour) do
      create(:working_hour,
        stylist: stylist,
        target_date: today,
        start_time: '10:00',
        end_time: '18:00')
    end

    before do
      sign_in stylist
      working_hour
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
    end

    it 'displays the set business hours' do
      expect(page).to have_css('th', text: '10:00')
      expect(page).to have_css('th', text: '10:30')
      expect(page).to have_css('th', text: '17:30')
      expect(page).to have_css('th', text: '18:00')
    end

    it 'displays rows for reservation count and remaining available slots' do
      expect(page).to have_css('th', text: '予約数')
      expect(page).to have_css('th', text: '残り枠')
    end

    # rubocop:disable RSpec/MultipleMemoizedHelpers
    describe 'changing available slots' do
      let(:slot_text) { '10:00' }
      let(:slot_index_to_test) { to_slot_index(slot_text) }

      def find_time_column_index(time_text)
        header_cells = page.all('thead tr th')
        target_index = header_cells.find_index { |th| th.text.strip == time_text.strip }

        raise "Header for time '#{time_text}' not found in thead" unless target_index

        target_index - 1
      end

      def find_target_slot_elements(time_text)
        column_index = find_time_column_index(time_text)
        target_row = find('tr', text: '残り枠')
        target_td = target_row.all('td')[column_index]
        value_div = target_td.find('div.font-bold')
        [target_td, value_div]
      end

      it 'can increase available slots and updates the database' do
        limit_record = ReservationLimit.find_or_create_by!(stylist: stylist, target_date: today,
          time_slot: slot_index_to_test) do |limit|
          limit.max_reservations = 1
        end
        initial_max_reservations = limit_record.max_reservations

        calculated_expected_max_after_increase = [initial_max_reservations + 1, 2].min
        expected_ui_text_after_increase = calculated_expected_max_after_increase.to_s

        target_td, _initial_value_div = find_target_slot_elements(slot_text)

        within(target_td) do
          # 増加ボタン（上向き矢印SVG）は最初のbutton
          all('button')[0].click
        end

        _updated_target_td, updated_value_div = find_target_slot_elements(slot_text)
        expect(updated_value_div).to have_text(expected_ui_text_after_increase, wait: 5)

        updated_limit_record_db = ReservationLimit.find_by!(stylist: stylist, target_date: today,
          time_slot: slot_index_to_test)
        expect(updated_limit_record_db.max_reservations).to eq(calculated_expected_max_after_increase)

        visit current_path
        _reloaded_target_td, reloaded_value_div = find_target_slot_elements(slot_text)
        expect(reloaded_value_div).to have_text(calculated_expected_max_after_increase.to_s)
      end

      it 'can decrease available slots and updates the database' do
        limit_record_setup = ReservationLimit.find_or_initialize_by(stylist: stylist, target_date: today,
          time_slot: slot_index_to_test)
        limit_record_setup.max_reservations = 2
        limit_record_setup.save!

        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))

        current_max_reservations_before_decrease = 2

        expected_db_value_after_decrease = [current_max_reservations_before_decrease - 1, 0].max
        expected_ui_text_after_decrease = expected_db_value_after_decrease.to_s

        target_td, _initial_value_div = find_target_slot_elements(slot_text)
        within(target_td) do
          # 減少ボタン（下向き矢印SVG）は2番目のbutton
          all('button')[1].click
        end

        _updated_target_td_decrease, updated_value_div_decrease = find_target_slot_elements(slot_text)
        expect(updated_value_div_decrease).to have_text(expected_ui_text_after_decrease, wait: 5)

        updated_limit_record_db_after_decrease = ReservationLimit.find_by!(stylist: stylist, target_date: today,
          time_slot: slot_index_to_test)
        expect(updated_limit_record_db_after_decrease.max_reservations).to eq(expected_db_value_after_decrease)

        visit current_path
        _reloaded_target_td, reloaded_value_div_after_decrease = find_target_slot_elements(slot_text)
        expect(reloaded_value_div_after_decrease).to have_text(expected_ui_text_after_decrease)
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end

  describe 'Reservation Display' do
    let(:reservation) do
      cut_menu = create(:menu, :cut, stylist: stylist, name: 'カット')
      color_menu = create(:menu, :color, stylist: stylist, name: 'カラー')
      r = Reservation.new(
        stylist: stylist,
        customer: customer,
        start_at: Time.zone.parse("#{today} 10:00"),
        end_at: Time.zone.parse("#{today} 11:00"),
        status: :before_visit
      )
      r.menus << cut_menu
      r.menus << color_menu
      r.save
      r
    end

    before do
      create(:working_hour,
        stylist: stylist,
        target_date: today,
        start_time: '10:00',
        end_time: '18:00')

      [10, 10.5].each do |hour|
        slot_time = hour == 10 ? '10:00' : '10:30'
        create(:reservation_limit,
          stylist: stylist,
          target_date: today,
          time_slot: to_slot_index(slot_time),
          max_reservations: 1)
      end

      sign_in stylist
      reservation
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
    end

    it 'displays reservation information' do
      expect(page).to have_content('カット, カラー')
      expect(page).to have_content("#{customer.family_name} #{customer.given_name} 様")
    end

    it 'correctly displays the remaining available slots' do
      slot_text = '10:00'

      within('tr', text: '残り枠') do
        all('td').each_with_index do |td, idx|
          next unless page.all('thead tr th')[idx + 1]&.text == slot_text

          within(td) do
            expect(page).to have_content('0')
            break
          end
        end
      end
    end

    it 'correctly displays the reservation count' do
      slot_text = '10:00'

      within('tr', text: '予約数') do
        all('td').each_with_index do |td, idx|
          if page.all('thead tr th')[idx + 1]&.text == slot_text
            expect(td).to have_text('1')
            break
          end
        end
      end
    end

    it 'navigates to the detail screen when a reservation is clicked' do
      find('a', text: 'カット, カラー').click

      expect(page).to have_current_path(%r{/stylists/reservations/#{reservation.id}})
    end
  end

  describe 'Holiday Display' do
    let(:today) { Date.new(2025, 5, 27) }
    let!(:stylist) { create(:user, :stylist) }

    before do
      create(:holiday, stylist: stylist, target_date: today, is_holiday: true)
      sign_in stylist
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
    end

    it 'displays the holiday message' do
      expect(page).to have_content('休業日')
    end
  end

  describe 'Date Navigation' do
    let(:tomorrow) { today + 1.day }
    let(:yesterday) { today - 1.day }

    before do
      sign_in stylist
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
    end

    it 'can navigate to the previous day\'s schedule' do
      find('a', text: '前の日').click
      expect(page).to have_content(I18n.l(yesterday, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{yesterday.strftime('%Y-%m-%d')}})
    end

    it 'can navigate to the next day\'s schedule' do
      find('a', text: '後の日').click
      expect(page).to have_content(I18n.l(tomorrow, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{tomorrow.strftime('%Y-%m-%d')}})
    end

    it 'displays date picker for date selection' do
      expect(page).to have_css('#schedule_date_picker', visible: :all)
      expect(page).to have_css('[onclick*="schedule_date_picker"]')
    end

    it 'navigates to selected date when date picker value changes', :js do
      target_date = today + 3.days

      page.execute_script("
        const datePicker = document.getElementById('schedule_date_picker');
        datePicker.value = '#{target_date.strftime('%Y-%m-%d')}';
        datePicker.dispatchEvent(new Event('change'));
      ")

      expect(page).to have_content(I18n.l(target_date, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{target_date.strftime('%Y-%m-%d')}})
    end

    it 'navigates to current stylist schedule when date picker changes', :js do
      other_stylist = create(:user, role: :stylist)
      target_date = today + 2.days

      create(:working_hour,
        stylist: other_stylist,
        target_date: target_date,
        start_time: '10:00',
        end_time: '18:00')

      page.execute_script("
        const datePicker = document.getElementById('schedule_date_picker');
        datePicker.value = '#{target_date.strftime('%Y-%m-%d')}';
        datePicker.dispatchEvent(new Event('change'));
      ")

      expect(page).to have_content(I18n.l(target_date, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{target_date.strftime('%Y-%m-%d')}})

      expect(page).to have_content('営業時間未設定')
    end
  end

  describe 'Access Restriction' do
    before do
      sign_in customer
    end

    it 'prevents non-stylists from accessing the schedule screen' do
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))

      expect(page).to have_current_path('/')
      expect(page).to have_no_css('h1', text: '予約表')
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe 'Two-tier Reservation Display' do
    # rubocop:disable RSpec/LetSetup
    let!(:working_hour) do
      create(:working_hour,
        stylist: stylist,
        target_date: today,
        start_time: '09:00',
        end_time: '12:00')
    end
    # rubocop:enable RSpec/LetSetup
    let!(:taro_customer) { create(:user, role: :customer, family_name: '予約', given_name: '太郎') }
    let!(:hanako_customer) { create(:user, role: :customer, family_name: '予約', given_name: '花子') }
    let!(:menu_cut) { create(:menu, stylist: stylist, name: 'カット', duration: 60) }

    before do
      sign_in stylist
    end

    context 'when all reservation limits are 1' do
      before do
        (to_slot_index('09:00')..to_slot_index('11:30')).each do |slot|
          create(:reservation_limit, stylist: stylist, target_date: today, time_slot: slot, max_reservations: 1)
        end
        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
      end

      it 'does not display the "予約2" row' do
        expect(page).to have_css("tr[data-testid='reservation-row-1']")
        expect(page).to have_no_css("tr[data-testid='reservation-row-2']")
      end
    end

    context 'when a slot has reservation limit of 2 or more' do
      before do
        create(:reservation_limit, stylist: stylist, target_date: today, time_slot: to_slot_index('09:00'),
          max_reservations: 2)
        (to_slot_index('09:30')..to_slot_index('11:30')).each do |slot|
          create(:reservation_limit, stylist: stylist, target_date: today, time_slot: slot, max_reservations: 1)
        end
      end

      it 'displays the "予約2" row' do
        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        expect(page).to have_css("tr[data-testid='reservation-row-1']")
        expect(page).to have_css("tr[data-testid='reservation-row-2']")
      end

      # rubocop:disable RSpec/NestedGroups
      context 'with two reservations starting at the same time' do
        let!(:taro_reservation) do
          create(:reservation, stylist: stylist, customer: taro_customer, menus: [menu_cut],
            start_at: Time.zone.parse("#{today} 09:00"), end_at: Time.zone.parse("#{today} 10:00"))
        end
        let!(:hanako_reservation) do
          create(:reservation, stylist: stylist, customer: hanako_customer, menus: [menu_cut],
            start_at: Time.zone.parse("#{today} 09:00"), end_at: Time.zone.parse("#{today} 09:30"))
        end

        before do
          create(:reservation_limit, stylist: stylist, target_date: today, time_slot: to_slot_index('09:30'),
            max_reservations: 1)
          visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        end

        it 'displays first reservation in "予約1" row and second in "予約2" row' do
          row1 = page.all('tbody tr')[2]
          within(row1) do
            taro_full_name = "#{taro_reservation.customer.family_name} #{taro_reservation.customer.given_name}"
            expect(page).to have_content(taro_full_name)
            taro_reservation_cell = find('td', text: /#{Regexp.escape(taro_full_name)}/)
            expect(taro_reservation_cell['colspan'].to_i).to eq 2
          end

          row2 = page.all('tbody tr')[3]
          within(row2) do
            hanako_full_name = "#{hanako_reservation.customer.family_name} #{hanako_reservation.customer.given_name}"
            expect(page).to have_content(hanako_full_name)
            hanako_reservation_cell = find('td', text: /#{Regexp.escape(hanako_full_name)}/)
            expect(hanako_reservation_cell['colspan'].to_i).to eq 1
          end
        end
      end
      # rubocop:enable RSpec/NestedGroups

      # rubocop:disable RSpec/NestedGroups
      context 'with overlapping reservations at different start times (10:30-11:30 and 11:00-12:00)' do
        let(:reservation_taro) do
          create(:reservation, stylist: stylist, customer: taro_customer, menus: [menu_cut],
            start_at: Time.zone.parse("#{today} 10:30"), end_at: Time.zone.parse("#{today} 11:30"))
        end
        let(:reservation_hanako) do
          create(:reservation, stylist: stylist, customer: hanako_customer, menus: [menu_cut],
            start_at: Time.zone.parse("#{today} 11:00"), end_at: Time.zone.parse("#{today} 12:00"))
        end

        before do
          limits_to_set = {
            to_slot_index('10:30') => 1,
            to_slot_index('11:00') => 2,
            to_slot_index('11:30') => 2,
            to_slot_index('12:00') => 2
          }

          limits_to_set.each do |slot_idx, max_val|
            limit = ReservationLimit.find_or_initialize_by(
              stylist: stylist,
              target_date: today,
              time_slot: slot_idx
            )
            limit.max_reservations = max_val
            limit.save!
          end

          reservation_taro
          reservation_hanako

          sign_in stylist
          visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        end

        it 'displays reservation A in "予約1" and reservation B in "予約2"' do
          row1 = find("tr[data-testid='reservation-row-1']")
          within(row1) do
            taro_full_name = "#{reservation_taro.customer.family_name} #{reservation_taro.customer.given_name}"
            reservation_a_cell = find('td', text: /#{Regexp.escape(taro_full_name)}/)
            expect(reservation_a_cell).to be_visible
            expect(reservation_a_cell['colspan'].to_i).to eq 2
          end

          row2 = find("tr[data-testid='reservation-row-2']")
          within(row2) do
            hanako_full_name = "#{reservation_hanako.customer.family_name} #{reservation_hanako.customer.given_name}"
            reservation_b_cell = find('td', text: /#{Regexp.escape(hanako_full_name)}/)
            expect(reservation_b_cell).to be_visible
            expect(reservation_b_cell['colspan'].to_i).to eq 2
          end
        end
      end
      # rubocop:enable RSpec/NestedGroups
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe 'Weekly Schedule View' do
    let(:start_date) { Date.current }
    let(:week_dates) { (start_date..(start_date + 6.days)).to_a }

    before do
      sign_in stylist
      week_dates.each do |date|
        create(:working_hour,
          stylist: stylist,
          target_date: date,
          start_time: '10:00',
          end_time: '18:00')
      end
    end

    it 'displays weekly view with navigation links' do
      visit stylists_schedules_path(date: start_date.strftime('%Y-%m-%d'))
      click_on '週間表示へ'
      expect(page).to have_content('週間予約表')
      expect(page).to have_link('日別表示へ')
      expect(page).to have_content('前の週')
      expect(page).to have_content('次の週')
    end

    it 'displays all days of the week with proper headers' do
      visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
      weekdays = %w[日 月 火 水 木 金 土]
      week_dates.each do |date|
        expect(page).to have_content(weekdays[date.wday])
        expect(page).to have_content(date.day.to_s)
      end
    end

    it 'displays time slots for the week' do
      visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
      expect(page).to have_content('10:00')
      expect(page).to have_content('10:30')
      expect(page).to have_content('17:30')
    end
    # rubocop:disable RSpec/MultipleMemoizedHelpers

    context 'with reservations' do
      let!(:menu) { create(:menu, stylist: stylist, name: 'カット', duration: 90) }
      let!(:reservation) do
        (to_slot_index('11:00')..to_slot_index('12:30')).each do |slot|
          create(:reservation_limit, stylist: stylist, target_date: start_date, time_slot: slot, max_reservations: 2)
        end
        create(:reservation,
          stylist: stylist,
          customer: customer,
          menus: [menu],
          start_at: Time.zone.parse("#{start_date} 11:00"),
          end_at: Time.zone.parse("#{start_date} 12:30"))
      end

      it 'displays reservation cards with vertical text' do
        visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
        expect(page).to have_content(customer.family_name)
        expect(page).to have_content(customer.given_name)
        expect(page).to have_content('カット')
      end

      it 'displays multi-slot reservations with proper rowspan' do
        visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
        reservation_cell = page.find('td', text: /#{customer.family_name}/)
        expect(reservation_cell['rowspan']).to eq('3')
      end

      it 'navigates to reservation detail when clicked' do
        visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
        find('a[href*="/stylists/reservations/"]').click
        expect(page).to have_current_path(%r{/stylists/reservations/#{reservation.id}})
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers

    # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'with holidays' do
      let(:holiday_date) { start_date + 2.days }

      before do
        create(:holiday, stylist: stylist, target_date: holiday_date, is_holiday: true)
      end

      it 'displays holiday dates with gray background' do
        visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
        holiday_cells = page.all('td.bg-slate-50')
        expect(holiday_cells.count).to be > 0
      end
    end

    # rubocop:enable RSpec/MultipleMemoizedHelpers

    it 'navigates between weeks' do
      visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
      find('a', text: '次の週').click
      next_week_start = start_date + 7.days
      expect(page).to have_current_path(%r{/stylists/schedules/weekly/#{next_week_start.strftime('%Y-%m-%d')}})
      find('a', text: '前の週').click
      expect(page).to have_current_path(%r{/stylists/schedules/weekly/#{start_date.strftime('%Y-%m-%d')}})
    end

    it 'navigates back to daily view' do
      visit stylists_weekly_schedules_path(start_date: start_date.strftime('%Y-%m-%d'))
      click_on '日別表示へ'
      expect(page).to have_current_path(%r{/stylists/schedules/#{start_date.strftime('%Y-%m-%d')}})
      expect(page).to have_content('予約表')
    end
  end
end
# rubocop:enable Metrics/BlockLength
