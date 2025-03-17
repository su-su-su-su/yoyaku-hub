# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customer Reservation Confirmation' do
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
    sign_in customer
  end

  def visit_reservation_confirmation(params = {})
    default_params = build_reservation_params

    visit new_customers_reservation_path(default_params.merge(params))
    expect_confirmation_page_loaded
  end

  def build_reservation_params
    {
      stylist_id: stylist.id,
      menu_ids: [menu.id],
      date: reservation_info[:date].to_s,
      time_str: reservation_info[:time]
    }
  end

  def expect_confirmation_page_loaded
    expect(page).to have_content('予約内容の確認')
    expect(page).to have_content('※まだ予約は確定していません')
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

  describe 'Displaying reservation confirmation screen' do
    before do
      visit_reservation_confirmation
    end

    it 'displays stylist information' do
      expect(page).to have_content(stylist.family_name)
      expect(page).to have_content(stylist.given_name)
    end

    it 'displays menu information' do
      expect(page).to have_content(menu.name)
    end

    it 'displays reservation date and time' do
      formatted_date = reservation_info[:date].strftime('%Y年%-m月%-d日')
      formatted_time = "#{reservation_info[:time].sub(':', '時')}分"

      expect(page).to have_content(formatted_date)
      expect(page).to have_content(formatted_time)
    end

    it 'displays total price' do
      expect(page).to have_content(menu.price.to_s)
    end

    it 'displays total service duration' do
      expect(page).to have_content(menu.duration.to_s)
      expect(page).to have_content('分')
    end
  end

  describe 'Reservation creation and confirmation screen transition' do
    context 'when creating a reservation with valid parameters' do
      it 'has a reservation confirmation button on the screen' do
        visit_reservation_confirmation

        expect(page).to have_current_path(%r{/customers/reservations/new})
        expect(page).to have_content('予約を確定するには下記の「予約を確定」をクリックしてください')

        expect(page).to have_button('予約を確定')

        form = find('form.button_to')
        form_action = URI.parse(form['action']).path
        expect(form_action).to eq('/customers/reservations')
        expect(form['method']).to eq('post')

        # rubocop:disable Capybara/SpecificMatcher, Capybara/VisibilityMatcher
        expect(page).to have_css('input[name="date"]', visible: false)
        expect(page).to have_css('input[name="menu_ids[]"]', visible: false)
        expect(page).to have_css('input[name="stylist_id"]', visible: false)
        expect(page).to have_css('input[name="time_str"]', visible: false)
        # rubocop:enable Capybara/SpecificMatcher, Capybara/VisibilityMatcher
      end
    end

    context 'when reservation conditions are edge cases' do
      def inactive_menu
        @inactive_menu ||= create(:menu, :inactive, stylist: stylist)
      end

      before do
        create(:holiday, stylist: stylist, target_date: reservation_info[:date], is_holiday: true)
      end

      it 'displays the confirmation screen but invalid conditions will be rejected during actual reservation' do
        test_cases = [
          { condition: '非表示メニュー', params: { menu_ids: [inactive_menu.id] } },
          { condition: '営業時間外', params: { time_str: '08:00' } },
          { condition: '施術終了時間が営業時間外', params: { time_str: '18:30' } },
          { condition: '休業日', params: {} }
        ]

        test_cases.each do |test_case|
          visit_reservation_confirmation(test_case[:params])
          expect(page).to have_content('予約内容の確認')
        end
      end
    end

    context 'when selecting multiple menus' do
      it 'displays all menus on the confirmation screen' do
        second_menu = create(:menu, :color, stylist: stylist, is_active: true)

        visit_reservation_confirmation(menu_ids: [menu.id, second_menu.id])

        expect(page).to have_content(menu.name)
        expect(page).to have_content(second_menu.name)

        total_price = menu.price + second_menu.price
        total_duration = menu.duration + second_menu.duration

        expect(page).to have_content(total_price.to_s)
        expect(page).to have_content(total_duration.to_s)
      end
    end
  end
end
