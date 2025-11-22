# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Customer Stylist Selection' do
  let(:users) do
    {
      customer: create(:customer),
      another_customer: create(:customer)
    }
  end

  let(:stylists) do
    {
      recent: create(:stylist, family_name: '山田', given_name: '太郎'),
      old: create(:stylist, family_name: '鈴木', given_name: '次郎'),
      other: create(:stylist, family_name: '佐藤', given_name: '花子')
    }
  end

  before do
    menus = {
      recent: create(:menu, stylist: stylists[:recent]),
      old: create(:menu, stylist: stylists[:old]),
      other: create(:menu, stylist: stylists[:other])
    }

    [stylists[:recent], stylists[:old], stylists[:other]].each do |stylist|
      (0..6).each do |day|
        create(:working_hour,
          stylist: stylist,
          day_of_week: day,
          target_date: nil,
          start_time: Time.zone.parse('09:00'),
          end_time: Time.zone.parse('18:00'))
      end

      allow(stylist).to receive(:working_hour_for_target_date)
        .with(Date.current)
        .and_return(
        instance_double(WorkingHour, start_time: Time.zone.parse('09:00'), end_time: Time.zone.parse('18:00'))
      )
    end

    one_year_ago = 1.year.ago
    reservation1 = build(:reservation,
      customer: users[:customer],
      stylist: stylists[:recent],
      start_date_str: Date.current.to_s,
      start_time_str: '10:00',
      menu_ids: [menus[:recent].id],
      created_at: one_year_ago,
      updated_at: one_year_ago)

    allow(reservation1).to receive(:validate_slotwise_capacity).and_return(true)
    reservation1.save!

    four_years_ago = 4.years.ago
    reservation2 = build(:reservation,
      customer: users[:customer],
      stylist: stylists[:old],
      start_date_str: Date.current.to_s,
      start_time_str: '11:00',
      menu_ids: [menus[:old].id],
      created_at: four_years_ago,
      updated_at: four_years_ago)

    allow(reservation2).to receive(:validate_slotwise_capacity).and_return(true)
    reservation2.save!

    reservation3 = build(:reservation,
      customer: users[:another_customer],
      stylist: stylists[:other],
      start_date_str: Date.current.to_s,
      start_time_str: '13:00',
      menu_ids: [menus[:other].id],
      created_at: one_year_ago,
      updated_at: one_year_ago)

    allow(reservation3).to receive(:validate_slotwise_capacity).and_return(true)
    reservation3.save!
  end

  describe 'stylist selection page' do
    context 'when logged in as a customer' do
      before do
        sign_in users[:customer]
        visit customers_stylists_index_path
      end

      it 'displays the correct page title' do
        expect(page).to have_css('h1', text: 'スタイリスト選択')
      end

      it 'displays explanatory text about the stylists shown' do
        expect(page).to have_content('過去3年以内に予約したことがあるスタイリストを表示しています')
      end

      it 'displays stylists booked within the last 3 years' do
        within('.stylist-list') do
          expect(page).to have_content("#{stylists[:recent].family_name} #{stylists[:recent].given_name}")
        end
      end

      it 'does not display stylists booked only more than 3 years ago' do
        expect(page).to have_no_content("#{stylists[:old].family_name} #{stylists[:old].given_name}")
      end

      it 'does not display stylists booked only by other customers' do
        expect(page).to have_no_content("#{stylists[:other].family_name} #{stylists[:other].given_name}")
      end

      it 'navigates to the menu selection page when clicking on a stylist' do
        stylist_name = "#{stylists[:recent].family_name} #{stylists[:recent].given_name}"
        find('.stylist-item', text: stylist_name).click

        expect(page).to have_current_path(
          customers_stylist_menus_path(stylist_id: stylists[:recent].id),
          wait: 5
        )
      end

      it 'returns to the dashboard when clicking the "Back" link' do
        click_on '戻る'
        expect(page).to have_current_path(customers_dashboard_path, wait: 5)
      end
    end

    context 'when logged in as a stylist' do
      before do
        sign_in stylists[:recent]
      end

      it 'restricts access to customer-only functionality' do
        visit customers_stylists_index_path
        expect(page).to have_current_path(root_path)
        expect(page).to have_content("フリーランス美容師の")
        expect(page).to have_content("予約・顧客・会計を")
        expect(page).to have_content("一元管理")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
