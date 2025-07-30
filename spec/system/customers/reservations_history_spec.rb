# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Customer Reservation History' do
  let(:customer) { create(:customer) }
  let(:stylist) { create(:stylist) }
  let(:menu) { create(:menu, stylist: stylist, is_active: true) }
  let(:reservation_info) do
    {
      date: Time.zone.today + 1.day,
      time: '13:00'
    }
  end

  before do
    setup_business_hours
    setup_reservation_dates
    sign_in customer
  end

  def setup_business_hours
    (0..6).each do |day|
      create(
        :working_hour,
        stylist: stylist,
        day_of_week: day,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('19:00')
      )
    end
  end

  def create_date_specific_working_hour(date)
    create(
      :working_hour,
      stylist: stylist,
      target_date: date,
      day_of_week: nil,
      start_time: Time.zone.parse('09:00'),
      end_time: Time.zone.parse('19:00')
    )
  end

  def remove_holidays(date)
    Holiday.where(stylist: stylist, target_date: date).destroy_all

    create(
      :holiday,
      stylist: stylist,
      target_date: date,
      is_holiday: false
    )
  end

  def setup_reservation_slots(date)
    (0..47).each do |slot|
      create(
        :reservation_limit,
        stylist: stylist,
        target_date: date,
        time_slot: slot,
        max_reservations: 1
      )
    end
  end

  def setup_reservation_dates
    dates = [
      reservation_info[:date],
      2.days.ago.to_date,
      3.days.from_now.to_date
    ]

    dates.each do |date|
      create_date_specific_working_hour(date)
      remove_holidays(date)
      setup_reservation_slots(date)
    end
  end

  def build_reservation(start_time, status)
    reservation = Reservation.new(
      customer_id: customer.id,
      stylist_id: stylist.id,
      start_at: start_time,
      end_at: start_time + menu.duration.minutes,
      status: status
    )
    reservation.save(validate: false)

    ReservationMenuSelection.create!(
      reservation: reservation,
      menu: menu
    )

    reservation
  end

  def create_future_reservation
    start_time = Time.zone.parse("#{reservation_info[:date]} #{reservation_info[:time]}")
    build_reservation(start_time, Reservation.statuses[:before_visit])
  end

  def create_past_reservation
    start_time = 2.days.ago
    build_reservation(start_time, Reservation.statuses[:paid])
  end

  def create_canceled_reservation
    start_time = 3.days.from_now
    build_reservation(start_time, Reservation.statuses[:canceled])
  end

  def visit_reservation_history
    visit customers_reservations_path
    expect(page).to have_content('予約履歴')
  end

  describe 'Viewing reservation history' do
    context 'when customer has no reservations' do
      before { visit_reservation_history }

      it 'displays empty state messages' do
        expect(page).to have_content('現在の予約はありません')
        expect(page).to have_content('過去の予約は存在しません')
      end
    end

    context 'when customer has upcoming reservations' do
      let!(:future_reservation) { create_future_reservation }

      before do
        create_past_reservation
        create_canceled_reservation
        visit_reservation_history
      end

      it 'displays upcoming reservations in current section' do
        expect(page).to have_content('現在の予約')
        expect(page).to have_content(future_reservation.stylist.family_name)
        expect(page).to have_content(I18n.l(future_reservation.start_at, format: :wday_short))
        expect(page).to have_content(menu.name)
      end
    end

    context 'when customer has past reservations' do
      let!(:past_reservations) { [create_past_reservation, create_canceled_reservation] }

      before do
        create_future_reservation
        visit_reservation_history
      end

      it 'displays past and canceled reservations in past section' do
        past_reservation = past_reservations[0]
        canceled_reservation = past_reservations[1]

        expect(page).to have_content('過去の予約')
        expect(page).to have_content(past_reservation.stylist.family_name)
        expect(page).to have_content(I18n.l(past_reservation.start_at, format: :wday_short))
        expect(page).to have_content(canceled_reservation.stylist.family_name)
        expect(page).to have_content(I18n.l(canceled_reservation.start_at, format: :wday_short))
      end
    end
  end

  describe 'Viewing reservation details' do
    context 'when viewing upcoming reservation details' do
      let!(:future_reservation) { create_future_reservation }

      before do
        visit_reservation_history
        click_on '詳細', match: :first
      end

      it 'displays reservation details correctly' do
        expect(page).to have_content('予約詳細')
        expect(page).to have_content("#{stylist.family_name} #{stylist.given_name}")
        expect(page).to have_content(I18n.l(future_reservation.start_at, format: :wday_short))
        expect(page).to have_content(menu.name)
        expect(page).to have_content("#{menu.duration} 分")
        expect(page).to have_content("¥#{menu.price}")
      end

      it 'shows cancel button for upcoming reservations' do
        expect(page).to have_link('キャンセル')
      end
    end

    context 'when viewing past reservation details' do
      let!(:past_reservation) { create_past_reservation }

      before do
        visit_reservation_history

        within all('.border.rounded-lg.bg-white').last do
          click_on '詳細'
        end
      end

      it 'displays reservation details correctly' do
        expect(page).to have_content('予約詳細')
        expect(page).to have_content("#{stylist.family_name} #{stylist.given_name}")
        expect(page).to have_content(I18n.l(past_reservation.start_at, format: :wday_short))
        expect(page).to have_content(menu.name)
        expect(page).to have_content("#{menu.duration} 分")
        expect(page).to have_content("¥#{menu.price}")
      end

      it 'does not show cancel button for past reservations' do
        expect(page).to have_no_link('キャンセル')
      end
    end
  end

  describe 'Canceling a reservation' do
    let!(:future_reservation) { create_future_reservation }

    before do
      visit_reservation_history
      click_on '詳細', match: :first
    end

    it 'shows a confirmation dialog when cancel is clicked' do
      accept_confirm('本当にキャンセルしますか？') do
        click_link_or_button 'キャンセル'
      end

      expect(page).to have_current_path(customers_reservations_path, ignore_query: true)
    end

    it 'moves the reservation to past reservations after cancellation' do
      page.accept_confirm do
        click_link_or_button 'キャンセル'
      end

      expect(page).to have_current_path(customers_reservations_path, ignore_query: true)
      expect(page).to have_content(I18n.t('stylists.reservations.cancelled'))

      expect(page).to have_content(stylist.family_name)
      expect(page).to have_content(I18n.l(future_reservation.start_at, format: :wday_short))

      expect(page).to have_content('現在の予約はありません')
    end
  end

  describe 'Navigation between pages' do
    before do
      create_future_reservation
      create_past_reservation
      visit_reservation_history
    end

    it 'allows navigation from history to detail page and back' do
      click_on '詳細', match: :first
      expect(page).to have_content('予約詳細')

      click_on '戻る'
      expect(page).to have_content('予約履歴')

      click_on '戻る'
      expect(page).to have_current_path(customers_dashboard_path)
    end
  end
end
# rubocop:enable Metrics/BlockLength
