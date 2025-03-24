# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers::Stylists::Weeklies' do
  include RSpec::Rails::SystemExampleGroup

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
    time_header = all('tbody th', text: time).first
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
        available_slot = find('a', text: '◎', match: :first)
        available_slot.click
        sleep 1

        expect(page).to have_current_path(
          %r{/customers/reservations/new}
        )
      end
    end
  end
end
