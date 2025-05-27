# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers::Stylists::Weeklies' do
  include RSpec::Rails::SystemExampleGroup

  def get_day_column_index_from_header(day)
    date_str = day.day.to_s
    day_char = %w[日 月 火 水 木 金 土][day.wday]
    day_column_index = nil

    within('thead') do
      all('th').each_with_index do |th, i|
        if th.text.include?("#{date_str} (#{day_char})")
          day_column_index = i
          break
        end
      end
    end
    day_column_index
  end

  def find_cell(time, day)
    time_header = first('tbody th', text: time)
    return nil unless time_header

    day_column_index = get_day_column_index_from_header(day)
    return nil unless day_column_index

    row = time_header.find(:xpath, './parent::tr')
    td_elements = row.all('td')

    target_td_index = day_column_index - 1
    return nil if target_td_index < 0 || target_td_index >= td_elements.count

    td_elements[target_td_index]
  end

  def check_time_slot(day, time, expected_mark)
    cell = find_cell(time, day)
    raise "Cell not found for time: #{time}, day: #{day.strftime('%Y-%m-%d')}" unless cell

    case expected_mark
    when '×'
      verify_cross_mark_in_cell(cell)
    when '◎', '△'
      verify_link_mark_in_cell(cell, expected_mark)
    else
      verify_other_mark_in_cell(cell, expected_mark, time, day)
    end
  end

  def verify_cross_mark_in_cell(cell)
    expect(cell).to have_content('×')
    expect(cell).to have_no_css('a')
  end

  def verify_link_mark_in_cell(cell, expected_link_text)
    expect(cell).to have_link(expected_link_text)
  end

  def verify_other_mark_in_cell(cell, expected_text, time, day)
    expect(cell.text.strip).to eq(expected_text),
      "Expected cell for #{time} on #{day.strftime('%Y-%m-%d')} to be '#{expected_text}', " \
      "but found '#{cell.text.strip}'."
  end

  def setup_slot_test_schedule(stylist_user, date_to_setup, start_hour: 10, end_hour: 19, default_max_reservations: 1)
    create(:working_hour,
      stylist: stylist_user,
      target_date: date_to_setup,
      start_time: Time.zone.parse("#{date_to_setup} #{format('%02d:00', start_hour)}"),
      end_time: Time.zone.parse("#{date_to_setup} #{format('%02d:00', end_hour)}"))

    start_slot_index = start_hour * 2
    end_slot_index = end_hour * 2

    (start_slot_index...end_slot_index).each do |slot_idx|
      create(:reservation_limit,
        stylist: stylist_user,
        target_date: date_to_setup,
        time_slot: slot_idx,
        max_reservations: default_max_reservations)
    end
  end

  def create_slot_test_reservation(cust, sty, day, start_time_str, end_time_str)
    create(:reservation, :before_visit,
      customer: cust,
      stylist: sty,
      start_at: Time.zone.parse("#{day} #{start_time_str}"),
      end_at: Time.zone.parse("#{day} #{end_time_str}"))
  end

  let(:base_date) { Date.new(2025, 3, 17) }

  let(:stylist) { create(:stylist) }
  let(:customer) { create(:customer) }
  let(:menu) { create(:menu, :cut, stylist: stylist, name: 'カット60分', is_active: true) }

  before do
    allow(Date).to receive(:current).and_return(base_date)
    allow(stylist).to receive(:min_active_menu_duration).and_return(60)

    setup_working_hours
    setup_reservations

    create(:holiday,
      stylist: stylist,
      target_date: base_date + 2.days,
      is_holiday: true)
  end

  def setup_working_hours
    dates = (base_date..(base_date + 2.days)).to_a

    dates.each do |date|
      create(:working_hour,
        stylist: stylist,
        target_date: date,
        start_time: Time.zone.parse("#{date} 10:00"),
        end_time: Time.zone.parse("#{date} 19:00"))

      (20..38).each do |slot|
        create(:reservation_limit,
          stylist: stylist,
          target_date: date,
          time_slot: slot,
          max_reservations: 1)
      end
    end
  end

  def create_reservation(day, start_time, end_time)
    start_time_str = format_time_string(start_time)
    end_time_str = format_time_string(end_time)

    create(:reservation, :before_visit,
      customer: customer,
      stylist: stylist,
      start_at: Time.zone.parse("#{day} #{start_time_str}"),
      end_at: Time.zone.parse("#{day} #{end_time_str}"))
  end

  def format_time_string(time)
    if time.is_a?(Float)
      hours = time.to_i
      minutes = ((time - hours) * 60).to_i
      format('%<hours>02d:%<minutes>02d', { hours: hours, minutes: minutes })
    else
      time.to_s
    end
  end

  def setup_reservations
    create_reservation(base_date, '10:30', '11:30')
    create_reservation(base_date + 1.day, '10:30', '11:30')
    create_reservation(base_date + 1.day, '13:00', '14:00')
  end

  def find_cell(time, day)
    time_header = first('tbody th', text: time)
    return nil unless time_header

    day_index = nil
    date_str = day.day.to_s
    day_char = %w[日 月 火 水 木 金 土][day.wday]

    within('thead') do
      all('th').each_with_index do |th, i|
        if th.text.include?("#{date_str} (#{day_char})")
          day_index = i
          break
        end
      end
    end

    return nil unless day_index

    row = time_header.find(:xpath, './parent::tr')
    row.all('td')[day_index - 1]
  end

  describe 'Authentication' do
    context 'when not logged in' do
      it 'redirects to login page' do
        visit weekly_customers_stylist_menus_path(stylist_id: stylist.id)
        expect(page).to have_current_path(new_user_session_path)
      end
    end

    context 'when logged in as non-customer' do
      before do
        sign_in create(:stylist)
        visit weekly_customers_stylist_menus_path(stylist_id: stylist.id)
      end

      it 'redirects from customer page' do
        expect(page).to have_no_current_path(
          weekly_customers_stylist_menus_path(stylist_id: stylist.id)
        )
      end
    end
  end

  describe 'Reservation display' do
    before do
      sign_in customer
    end

    context 'when today is a Wednesday (to test calendar starting day)' do
      let(:wednesday) { Date.new(2025, 3, 19) }

      before do
        allow(Date).to receive(:current).and_return(wednesday)

        Holiday.find_by(target_date: wednesday)&.destroy
        WorkingHour.find_by(stylist: stylist, target_date: wednesday)&.destroy
        create(:working_hour, stylist: stylist, target_date: wednesday,
          start_time: Time.zone.parse("#{wednesday} 10:00"), end_time: Time.zone.parse("#{wednesday} 19:00"))
        (20..38).each do |slot|
          create(:reservation_limit, stylist: stylist, target_date: wednesday, time_slot: slot, max_reservations: 1)
        end

        visit weekly_customers_stylist_menus_path(
          stylist_id: stylist.id,
          menu_ids: [menu.id]
        )
        sleep 1
      end

      it 'starts the calendar from today (Wednesday), not from Monday' do
        expected_start_date = wednesday.strftime('%-m月%-d日')
        expected_end_date = (wednesday + 6.days).strftime('%-m月%-d日')
        expect(page).to have_content("#{expected_start_date}〜#{expected_end_date}")

        headers = all('thead th').map(&:text)
        expect(headers[1]).to include("#{wednesday.day} (水)")

        monday = wednesday.beginning_of_week
        expect(headers[1]).not_to include("#{monday.day} (月)")
      end
    end

    context 'when viewing weekly calendar after menu selection' do
      before do
        visit weekly_customers_stylist_menus_path(
          stylist_id: stylist.id,
          menu_ids: [menu.id]
        )
        sleep 1
      end

      it 'displays correct date range for the week' do
        expected_range = "#{base_date.strftime('%-m月%-d日')}〜#{(base_date + 6.days).strftime('%-m月%-d日')}"
        expect(page).to have_content(expected_range)
        expect(page).to have_current_path(
          %r{/customers/stylists/\d+/menus/weekly}
        )
      end

      it 'displays time slots based on business hours' do
        business_hours = ['10:00', '10:30', '18:00', '18:30']
        expect(business_hours.any? { |time| page.has_css?('table tbody tr th', text: time) }).to be true

        non_business = ['06:00', '07:00', '08:00', '09:00', '20:00', '21:00']
        expect(non_business.any? { |time| page.has_css?('table tbody tr th', text: time) }).to be false
      end

      it 'displays X marks in holiday column' do
        wednesday = base_date + 2.days
        wed_str = "#{wednesday.day} (水)"

        header = all('thead th').find { |th| th.text.include?(wed_str) }
        header_index = all('thead th').index(header)

        return unless header_index

        all('tbody tr').each do |row|
          cell = row.all('td')[header_index - 1]
          expect(cell).to have_content('×') if cell
        end
      end
    end

    context 'when checking time slot availability' do
      before do
        visit weekly_customers_stylist_menus_path(
          stylist_id: stylist.id,
          menu_ids: [menu.id]
        )
        sleep 1
      end

      it 'shows X marks for booked time slots' do
        monday = base_date
        tuesday = base_date + 1.day

        occupied_slots = [
          { day: monday, time: '10:30' },
          { day: monday, time: '11:00' },
          { day: tuesday, time: '10:30' },
          { day: tuesday, time: '11:00' },
          { day: tuesday, time: '13:00' },
          { day: tuesday, time: '13:30' }
        ]

        occupied_slots.each do |slot|
          cell = find_cell(slot[:time], slot[:day])
          expect(cell).to be_present
          expect(cell).to have_content('×')
        end
      end

      def check_time_slot(day, time, expected_mark)
        cell = find_cell(time, day)
        return unless cell

        if expected_mark == '×'
          expect(cell).to have_content('×')
        elsif cell.has_css?('a')
          link_text = cell.find('a').text
          if expected_mark == '◎'
            expect(link_text).to eq('◎')
          else
            expect(link_text).to eq('△')
          end
        end
      end

      it 'checks time slot markers for scenario A (Monday)' do
        monday = base_date

        time_with_x = find_cell('10:00', monday)
        expect(time_with_x).to have_content('×')

        time_with_circle = find_cell('11:30', monday)
        if time_with_circle&.has_css?('a')
          link_text = time_with_circle.find('a').text
          expect(link_text).to eq('◎')
        end

        time_with_triangle = find_cell('12:00', monday)
        if time_with_triangle&.has_css?('a')
          link_text = time_with_triangle.find('a').text
          expect(link_text).to eq('△')
        end
      end

      it 'checks time slot markers for scenario B (Tuesday)' do
        tuesday = base_date + 1.day

        expect(page).to have_css('table thead th', text: "#{tuesday.day} (火)")

        check_time_slot(tuesday, '10:00', '×')
        check_time_slot(tuesday, '12:30', '×')

        check_time_slot(tuesday, '11:30', '◎')
        check_time_slot(tuesday, '12:00', '◎')
        check_time_slot(tuesday, '14:00', '◎')
        check_time_slot(tuesday, '14:30', '△')
        check_time_slot(tuesday, '15:00', '◎')
      end

      it 'navigates to reservation confirmation page when clicking available time slot' do
        available_slot = first('a', text: '◎')
        available_slot.click
        sleep 1

        expect(page).to have_current_path(
          %r{/customers/reservations/new}
        )
      end
    end
  end

  describe 'Reservation symbols guide card display' do
    let(:card_display_stylist) { create(:stylist, email: 'card_display_stylist_revised@example.com') }
    let(:card_display_customer) { create(:customer, email: 'card_display_customer_revised@example.com') }

    let(:guide_card_selector) { '.mt-6.p-4.border.rounded-lg.bg-white.shadow' }
    let(:guide_card_title_text) { '予約表の記号について' }

    before do
      sign_in card_display_customer
    end

    describe 'when the card should be displayed' do
      context 'with all active menus being longer than 30 minutes' do
        it 'displays the reservation symbols guide card' do
          menu_long_active = create(:menu, stylist: card_display_stylist, name: 'カット', duration: 60, is_active: true)
          create(:menu, stylist: card_display_stylist, name: 'パーマ', duration: 120, is_active: true)
          visit weekly_customers_stylist_menus_path(stylist_id: card_display_stylist.id,
            menu_ids: [menu_long_active.id])
          expect(page).to have_selector(guide_card_selector, text: guide_card_title_text)
        end
      end

      context 'with 30-minute-or-less menus existing but all being inactive' do
        it 'displays the reservation symbols guide card' do
          create(:menu, stylist: card_display_stylist, name: 'クイックトリートメント(非掲載)', duration: 30, is_active: false)
          menu_for_navigation = create(:menu, stylist: card_display_stylist, name: 'カラー', duration: 90,
            is_active: true)

          visit weekly_customers_stylist_menus_path(stylist_id: card_display_stylist.id,
            menu_ids: [menu_for_navigation.id])
          expect(page).to have_selector(guide_card_selector, text: guide_card_title_text)
        end
      end
    end

    describe 'when the card should NOT be displayed' do
      context 'with an active menu of 30 minutes or less' do
        let!(:menu_short_active) do
          create(:menu, stylist: card_display_stylist, name: 'ショートスパ(掲載中)', duration: 30, is_active: true)
        end

        before do
          create(:menu, stylist: card_display_stylist, name: 'カット', duration: 60, is_active: true)
        end

        it 'does NOT display the reservation symbols guide card' do
          visit weekly_customers_stylist_menus_path(stylist_id: card_display_stylist.id,
            menu_ids: [menu_short_active.id])

          expect(page).to have_current_path(%r{/customers/stylists/\d+/menus/weekly})
          expect(page).to have_no_selector(guide_card_selector, text: guide_card_title_text)
        end
      end
    end

    describe 'Reservation slot symbol display logic' do
      let(:slot_test_stylist) { create(:stylist, email: 'slot_logic_stylist@example.com') }
      let(:slot_test_customer) { create(:customer, email: 'slot_logic_customer@example.com') }
      let(:card_test_base_date) { Date.new(2025, 3, 17) }

      before do
        allow(Date).to receive(:current).and_return(card_test_base_date)
        allow(Time).to receive(:current).and_return(Time.zone.parse("#{card_test_base_date} 08:00:00"))
        sign_in slot_test_customer
      end

      context 'when min_active_menu_duration is 60 minutes' do
        before do
          allow(slot_test_stylist).to receive(:min_active_menu_duration).and_return(60)
          setup_slot_test_schedule(slot_test_stylist, card_test_base_date)
        end

        context 'with a selected menu of 60 minutes' do
          let(:menu_60_min) { create(:menu, stylist: slot_test_stylist, duration: 60, name: 'TestCut 60min') }

          context 'with no existing reservations' do
            it 'shows ◎ for most slots, and × for slots too late' do
              visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_60_min.id])
              check_time_slot(card_test_base_date, '10:00', '◎')
              check_time_slot(card_test_base_date, '17:30', '△')
              check_time_slot(card_test_base_date, '18:00', '◎')
              check_time_slot(card_test_base_date, '18:30', '×')
            end
          end

          context 'with an existing reservation at 10:30-11:30 (Scenario A like)' do
            before do
              create_slot_test_reservation(slot_test_customer, slot_test_stylist, card_test_base_date, '10:30', '11:30')
            end

            it 'shows correct symbols around the reservation' do
              visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_60_min.id])
              check_time_slot(card_test_base_date, '10:00', '×')
              check_time_slot(card_test_base_date, '10:30', '×')
              check_time_slot(card_test_base_date, '11:00', '×')
              check_time_slot(card_test_base_date, '11:30', '◎')
              check_time_slot(card_test_base_date, '12:00', '△')
              check_time_slot(card_test_base_date, '12:30', '◎')
            end
          end

          context 'with reservations at 10:30-11:30 and 13:00-14:00 (Scenario B like)' do
            before do
              create_slot_test_reservation(slot_test_customer, slot_test_stylist, card_test_base_date, '10:30', '11:30')
              create_slot_test_reservation(slot_test_customer, slot_test_stylist, card_test_base_date, '13:00', '14:00')
            end

            it 'shows ◎ at 11:30, ◎ at 12:00, and × at 12:30' do
              visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_60_min.id])
              check_time_slot(card_test_base_date, '11:30', '◎')
              check_time_slot(card_test_base_date, '12:00', '◎')
              check_time_slot(card_test_base_date, '12:30', '×')
            end
          end
        end
      end

      context 'when min_active_menu_duration is 30 minutes' do
        before do
          allow(slot_test_stylist).to receive(:min_active_menu_duration).and_return(30)
          setup_slot_test_schedule(slot_test_stylist, card_test_base_date)
        end

        context 'with a selected menu of 30 minutes' do
          let(:menu_30_min) { create(:menu, stylist: slot_test_stylist, duration: 30, name: 'TestQuick 30min') }

          it 'shows ◎ for most slots, and no △' do
            visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_30_min.id])
            check_time_slot(card_test_base_date, '10:00', '◎')
            check_time_slot(card_test_base_date, '18:00', '◎')
            check_time_slot(card_test_base_date, '18:30', '◎')
          end

          context 'with an existing reservation at 10:30-11:00' do
            before do
              create_slot_test_reservation(slot_test_customer, slot_test_stylist, card_test_base_date, '10:30', '11:00')
            end

            it 'shows ◎ for adjacent slots' do
              visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_30_min.id])
              check_time_slot(card_test_base_date, '10:00', '◎')
              check_time_slot(card_test_base_date, '10:30', '×')
              check_time_slot(card_test_base_date, '11:00', '◎')
            end
          end
        end
      end

      context 'when min_active_menu_duration is 60 minutes and selected menu is 120 minutes' do
        let(:menu_120_min) { create(:menu, stylist: slot_test_stylist, duration: 120, name: 'TestLong 120min') }

        before do
          allow(slot_test_stylist).to receive(:min_active_menu_duration).and_return(60)
          slot_test_stylist.working_hours.where(target_date: card_test_base_date).destroy_all
          slot_test_stylist.reservation_limits.where(target_date: card_test_base_date).destroy_all
          setup_slot_test_schedule(slot_test_stylist, card_test_base_date, start_hour: 11, end_hour: 20)

          create_slot_test_reservation(slot_test_customer, slot_test_stylist, card_test_base_date, '16:00', '17:00')
        end

        it 'shows ◎ at 17:00, △ at 17:30, ◎ at 18:00' do
          visit weekly_customers_stylist_menus_path(stylist_id: slot_test_stylist.id, menu_ids: [menu_120_min.id])
          check_time_slot(card_test_base_date, '17:00', '◎')
          check_time_slot(card_test_base_date, '17:30', '△')
          check_time_slot(card_test_base_date, '18:00', '◎')
        end
      end

      context 'when reservation_limit is 2 for a slot and one reservation exists' do
        let(:test_target_date) { card_test_base_date }
        let(:menu_for_this_test) do
          create(:menu, stylist: slot_test_stylist, duration: 30, name: 'Quick Test 30min', is_active: true)
        end
        let(:target_time_str) { '10:00' }

        before do
          allow(slot_test_stylist).to receive(:min_active_menu_duration).and_return(30)

          setup_slot_test_schedule(
            slot_test_stylist,
            test_target_date,
            start_hour: 10,
            end_hour: 19,
            default_max_reservations: 1
          )

          hour, minute = target_time_str.split(':').map(&:to_i)
          calculated_target_slot_number = (hour * 2) + (minute >= 30 ? 1 : 0)

          reservation_limit_for_target_slot = ReservationLimit.find_by(
            stylist: slot_test_stylist,
            target_date: test_target_date,
            time_slot: calculated_target_slot_number
          )
          if reservation_limit_for_target_slot
            reservation_limit_for_target_slot.update!(max_reservations: 2)
          else
            create(:reservation_limit,
              stylist: slot_test_stylist,
              target_date: test_target_date,
              time_slot: target_slot_number,
              max_reservations: 2)
          end

          create_slot_test_reservation(
            slot_test_customer,
            slot_test_stylist,
            test_target_date,
            target_time_str,
            '10:30'
          )
        end

        it 'shows "◎" for the slot, indicating it is still available' do
          visit weekly_customers_stylist_menus_path(
            stylist_id: slot_test_stylist.id,
            menu_ids: [menu_for_this_test.id]
          )
          check_time_slot(test_target_date, target_time_str, '◎')
        end
      end
    end
  end
end
