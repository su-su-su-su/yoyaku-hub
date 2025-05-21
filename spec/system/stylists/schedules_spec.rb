# frozen_string_literal: true

require 'rails_helper'

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
        expect(page).to have_link('前の日へ')
        expect(page).to have_link('後の日へ')
      end

      it 'displays message when business hours are not set' do
        expect(page).to have_content('営業時間が設定されていません')
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
      expect(page).to have_css('th', text: '残り受付可能数')
    end

    describe 'changing available slots' do
      let(:slot_text) { '10:00' }
      let(:slot_index_to_test) { to_slot_index(slot_text) }

      def find_target_slot_elements(time_text_arg)
        target_column_idx = -1
        page.all('thead tr th').each_with_index do |th, idx|
          if th.text.strip == time_text_arg.strip
            target_column_idx = idx - 1
            break
          end
        end
        raise "Header for time '#{time_text_arg}' not found in thead" if target_column_idx == -1

        target_row = find('tr', text: '残り受付可能数')
        raise "Row with text '残り受付可能数' not found" unless target_row.present?

        all_tds_in_row = target_row.all('td')
        raise "No tds found in the target row" if all_tds_in_row.empty?
        raise "Calculated td_index #{target_column_idx} is out of bounds for tds (count: #{all_tds_in_row.count})" if target_column_idx < 0 || target_column_idx >= all_tds_in_row.count

        target_td = all_tds_in_row[target_column_idx]
        value_div = target_td.find('div.font-medium')
        return target_td, value_div
      end

      it 'can increase available slots and updates the database' do
        limit_record = ReservationLimit.find_or_create_by!(stylist: stylist, target_date: today, time_slot: slot_index_to_test) do |limit|
          limit.max_reservations = 1
        end
        initial_max_reservations = limit_record.max_reservations

        calculated_expected_max_after_increase = [initial_max_reservations + 1, 2].min
        expected_ui_text_after_increase = calculated_expected_max_after_increase.to_s

        target_td, _initial_value_div = find_target_slot_elements(slot_text)

        within(target_td) do
          click_on '▲'
        end

        _updated_target_td, updated_value_div = find_target_slot_elements(slot_text)
        expect(updated_value_div).to have_text(expected_ui_text_after_increase, wait: 5)

        updated_limit_record_db = ReservationLimit.find_by!(stylist: stylist, target_date: today, time_slot: slot_index_to_test)
        expect(updated_limit_record_db.max_reservations).to eq(calculated_expected_max_after_increase)

        visit current_path
        _reloaded_target_td, reloaded_value_div = find_target_slot_elements(slot_text)
        expect(reloaded_value_div).to have_text(calculated_expected_max_after_increase.to_s)
      end

      it 'can decrease available slots and updates the database' do
        limit_record_setup = ReservationLimit.find_or_initialize_by(stylist: stylist, target_date: today, time_slot: slot_index_to_test)
        limit_record_setup.max_reservations = 2
        limit_record_setup.save!

        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))

        current_max_reservations_before_decrease = 2

        expected_db_value_after_decrease = [current_max_reservations_before_decrease - 1, 0].max
        expected_ui_text_after_decrease = expected_db_value_after_decrease.to_s

        target_td, _initial_value_div = find_target_slot_elements(slot_text)
        within(target_td) do
          click_on '▼'
        end

        _updated_target_td_decrease, updated_value_div_decrease = find_target_slot_elements(slot_text)
        expect(updated_value_div_decrease).to have_text(expected_ui_text_after_decrease, wait: 5)

        updated_limit_record_db_after_decrease = ReservationLimit.find_by!(stylist: stylist, target_date: today, time_slot: slot_index_to_test)
        expect(updated_limit_record_db_after_decrease.max_reservations).to eq(expected_db_value_after_decrease)

        visit current_path
        _reloaded_target_td, reloaded_value_div_after_decrease = find_target_slot_elements(slot_text)
        expect(reloaded_value_div_after_decrease).to have_text(expected_ui_text_after_decrease)
      end
    end
  end

  describe 'Reservation Display' do
    let(:cut_menu) { create(:menu, :cut, stylist: stylist, name: 'カット') }
    let(:color_menu) { create(:menu, :color, stylist: stylist, name: 'カラー') }
    let(:reservation) do
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

      within('tr', text: '残り受付可能数') do
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
      find('a', text: 'カット, カラー' ).click

      expect(page).to have_current_path(%r{/stylists/reservations/#{reservation.id}})
    end
  end

  describe 'Holiday Display' do
    before do
      allow(Holiday).to receive(:default_for).with(stylist.id, today).and_return(true)
      sign_in stylist
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
    end

    it 'displays the holiday message' do
      expect(page).to have_content('休業日です')
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
      click_on '前の日へ'
      expect(page).to have_content(I18n.l(yesterday, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{yesterday.strftime('%Y-%m-%d')}})
    end

    it 'can navigate to the next day\'s schedule' do
      click_on '後の日へ'
      expect(page).to have_content(I18n.l(tomorrow, format: :long))
      expect(page).to have_current_path(%r{/stylists/schedules/#{tomorrow.strftime('%Y-%m-%d')}})
    end
  end

  describe 'Access Restriction' do
    before do
      sign_in customer
    end

    it 'prevents non-stylists from accessing the schedule screen' do
      visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))

      expect(page).to have_no_css('h1', text: '予約表')
      expect(page).to have_current_path('/')
    end
  end

  describe 'Two-tier Reservation Display' do
    let!(:working_hour) do
      create(:working_hour,
             stylist: stylist,
             target_date: today,
             start_time: '09:00',
             end_time: '12:00')
    end
    let!(:customer1) { create(:user, role: :customer, family_name: '予約', given_name: '太郎') }
    let!(:customer2) { create(:user, role: :customer, family_name: '予約', given_name: '花子') }
    let!(:customer3) { create(:user, role: :customer, family_name: '予約', given_name: '次郎') }
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
        expect(page).to have_selector("tr[data-testid='reservation-row-1']")
        expect(page).not_to have_selector("tr[data-testid='reservation-row-2']")
      end
    end

    context 'when a slot has reservation limit of 2 or more' do
      before do
        create(:reservation_limit, stylist: stylist, target_date: today, time_slot: to_slot_index('09:00'), max_reservations: 2)
        (to_slot_index('09:30')..to_slot_index('11:30')).each do |slot|
          create(:reservation_limit, stylist: stylist, target_date: today, time_slot: slot, max_reservations: 1)
        end
      end

      it 'displays the "予約2" row' do
        visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        expect(page).to have_selector("tr[data-testid='reservation-row-1']")
        expect(page).to have_selector("tr[data-testid='reservation-row-2']")
      end

      context 'with two reservations starting at the same time' do
        let!(:reservation1) do
          create(:reservation, stylist: stylist, customer: customer1, menus: [menu_cut],
                               start_at: Time.zone.parse("#{today} 09:00"), end_at: Time.zone.parse("#{today} 10:00"))
        end
        let!(:reservation2) do
          create(:reservation, stylist: stylist, customer: customer2, menus: [menu_cut],
                               start_at: Time.zone.parse("#{today} 09:00"), end_at: Time.zone.parse("#{today} 09:30"))
        end

        before do
          create(:reservation_limit, stylist: stylist, target_date: today, time_slot: to_slot_index('09:30'), max_reservations: 1)
          visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        end

        it 'displays first reservation in "予約1" row and second in "予約2" row' do
          row1 = page.all('tbody tr')[2]
          within(row1) do
            customer1_full_name_text = "#{reservation1.customer.family_name} #{reservation1.customer.given_name}"
            expect(page).to have_content(customer1_full_name_text)
            reservation1_cell = find('td', text: /#{Regexp.escape(customer1_full_name_text)}/)
            expect(reservation1_cell['colspan'].to_i).to eq 2
          end

          row2 = page.all('tbody tr')[3]
          within(row2) do
            customer2_full_name_text = "#{reservation2.customer.family_name} #{reservation2.customer.given_name}"
            expect(page).to have_content(customer2_full_name_text)
            reservation2_cell = find('td', text: /#{Regexp.escape(customer2_full_name_text)}/)
            expect(reservation2_cell['colspan'].to_i).to eq 1
          end
        end
      end

      context 'with overlapping reservations at different start times (10:30-11:30 and 11:00-12:00)' do
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

          @reservation_A = create(:reservation, stylist: stylist, customer: customer1, menus: [menu_cut],
                                 start_at: Time.zone.parse("#{today} 10:30"), end_at: Time.zone.parse("#{today} 11:30"))

          @reservation_B = create(:reservation, stylist: stylist, customer: customer2, menus: [menu_cut],
                                   start_at: Time.zone.parse("#{today} 11:00"), end_at: Time.zone.parse("#{today} 12:00"))

          sign_in stylist
          visit stylists_schedules_path(date: today.strftime('%Y-%m-%d'))
        end

        it 'displays reservation A in "予約1" and reservation B in "予約2"' do
          row1 = find("tr[data-testid='reservation-row-1']")
          within(row1) do
            customer1_full_name_text = "#{@reservation_A.customer.family_name} #{@reservation_A.customer.given_name}"
            reservation_a_cell = find('td', text: /#{Regexp.escape(customer1_full_name_text)}/)
            expect(reservation_a_cell).to be_visible
            expect(reservation_a_cell['colspan'].to_i).to eq 2
          end

          row2 = find("tr[data-testid='reservation-row-2']")
          within(row2) do
            customer2_full_name_text = "#{@reservation_B.customer.family_name} #{@reservation_B.customer.given_name}"
            reservation_b_cell = find('td', text: /#{Regexp.escape(customer2_full_name_text)}/)
            expect(reservation_b_cell).to be_visible
            expect(reservation_b_cell['colspan'].to_i).to eq 2
          end
        end
      end
    end
  end
end
