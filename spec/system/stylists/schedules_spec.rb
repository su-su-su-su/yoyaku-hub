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

      it 'can increase available slots' do
        within('tr', text: '残り受付可能数') do
          all('td').each_with_index do |td, idx|
            next unless page.all('thead tr th')[idx + 1]&.text == slot_text

            within(td) do
              click_on '▲'
              break
            end
          end
        end

        visit current_path

        within('tr', text: '残り受付可能数') do
          all('td').each_with_index do |td, idx|
            next unless page.all('thead tr th')[idx + 1]&.text == slot_text

            within(td) do
              expect(page).to have_content('1')
              break
            end
          end
        end
      end

      it 'can decrease available slots' do
        within('tr', text: '残り受付可能数') do
          all('td').each_with_index do |td, idx|
            next unless page.all('thead tr th')[idx + 1]&.text == slot_text

            within(td) do
              click_on '▲'
              break
            end
          end
        end

        visit current_path

        within('tr', text: '残り受付可能数') do
          all('td').each_with_index do |td, idx|
            next unless page.all('thead tr th')[idx + 1]&.text == slot_text

            within(td) do
              click_on '▼'
              break
            end
          end
        end

        visit current_path

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
end
