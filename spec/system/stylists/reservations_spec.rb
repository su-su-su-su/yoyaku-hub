# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylists::Reservations' do
  let(:stylist) { create(:user, role: :stylist) }
  let(:customer) { create(:user, role: :customer) }
  let(:today) { Date.current }
  let(:menus) do
    [create(:menu, :cut, stylist: stylist, name: 'カット'), create(:menu, :color, stylist: stylist, name: 'カラー')]
  end

  before do
    create(:working_hour,
      stylist: stylist,
      target_date: today,
      start_time: '10:00',
      end_time: '18:00')
    sign_in stylist
  end

  def to_slot_index(time_str)
    h, m = time_str.split(':').map(&:to_i)
    (h * 2) + (m >= 30 ? 1 : 0)
  end

  def create_reservation_limits
    [10, 10.5].each do |hour|
      slot_time = hour == 10 ? '10:00' : '10:30'
      create(:reservation_limit,
        stylist: stylist,
        target_date: today,
        time_slot: to_slot_index(slot_time),
        max_reservations: 1)
    end
  end

  def create_test_reservation
    create_reservation_limits

    r = Reservation.new(
      stylist: stylist,
      customer: customer,
      start_at: Time.zone.parse("#{today} 10:00"),
      end_at: Time.zone.parse("#{today} 11:00"),
      status: :before_visit
    )
    r.menus = menus
    r.save
    r
  end

  describe 'Reservation Detail Function' do
    context 'when displaying reservation details' do
      let(:reservation) { create_test_reservation }

      before do
        visit stylists_reservation_path(reservation)
      end

      it 'displays basic information correctly' do
        expect(page).to have_content(I18n.l(reservation.start_at, format: :wday_short))
        expect(page).to have_content(customer.family_name.to_s)
        expect(page).to have_content("#{customer.given_name} 様")
      end

      it 'displays menu information' do
        expect(page).to have_content('カット')
        expect(page).to have_content('カラー')
      end

      it 'displays treatment duration' do
        duration_minutes = ((reservation.end_at - reservation.start_at) / 60).to_i
        expect(page).to have_content("#{duration_minutes} 分")
      end

      it 'displays total price' do
        cut_menu = menus.find { |m| m.name == 'カット' }
        color_menu = menus.find { |m| m.name == 'カラー' }
        total_price = cut_menu.price + color_menu.price
        expect(page).to have_content("¥#{total_price} (税込み)")
      end
    end

    context 'when canceling a reservation' do
      let(:reservation) { create_test_reservation }

      before do
        visit stylists_reservation_path(reservation)
      end

      it 'displays confirmation dialog and can cancel the reservation' do
        accept_confirm do
          click_on 'キャンセル'
        end

        expect(page).to have_content('予約表')
        expect(page).to have_content(I18n.l(today, format: :long))

        expect(page).to have_no_content('カット')
        expect(page).to have_no_content('カラー')

        within('tr', text: '残り受付可能数') do
          all('td').each_with_index do |td, idx|
            next unless page.all('thead tr th')[idx + 1]&.text == '10:00'

            within(td) do
              expect(page).to have_content('1')
              break
            end
          end
        end
      end
    end

    context 'when displaying the reservation edit screen' do
      let(:reservation) { create_test_reservation }

      before do
        visit stylists_reservation_path(reservation)
      end

      it 'navigates to the edit screen' do
        click_on '変更する'
        expect(page).to have_content('予約の変更')
      end

      it 'displays existing reservation information on the edit screen' do
        cut_menu = menus.find { |m| m.name == 'カット' }
        color_menu = menus.find { |m| m.name == 'カラー' }

        click_on '変更する'

        expect(page).to have_field('reservation[start_date_str]', with: today.strftime('%Y-%m-%d'))
        expect(page).to have_select('reservation[start_time_str]', selected: '10:00')
        expect(page).to have_checked_field('reservation[menu_ids][]', with: cut_menu.id.to_s)
        expect(page).to have_checked_field('reservation[menu_ids][]', with: color_menu.id.to_s)

        total_duration = cut_menu.duration + color_menu.duration
        expect(page).to have_select('reservation[custom_duration]', selected: "#{total_duration}分")
      end
    end

    context 'when modifying a reservation' do
      let(:reservation) { create_test_reservation }

      before do
        visit stylists_reservation_path(reservation)
        click_on '変更する'
      end

      it 'can modify and save reservation information' do
        cut_menu = menus.find { |m| m.name == 'カット' }
        color_menu = menus.find { |m| m.name == 'カラー' }

        if page.has_checked_field?('reservation[menu_ids][]', with: color_menu.id.to_s)
          uncheck 'reservation[menu_ids][]', with: color_menu.id.to_s
        end

        check 'reservation[menu_ids][]', with: cut_menu.id.to_s
        select "#{cut_menu.duration}分", from: 'reservation[custom_duration]'
        click_on '変更を確定'

        expect(page).to have_content('予約詳細')
        expect(page).to have_content('予約が正常に更新されました')
        expect(page).to have_content('カット')
        expect(page).to have_no_content('カラー')
        expect(page).to have_content("#{cut_menu.duration} 分")
        expect(page).to have_content("¥#{cut_menu.price} (税込み)")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
