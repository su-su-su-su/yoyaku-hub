# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationMenuSelection do
  let(:stylist) { create(:user, :stylist) }
  let(:customer) { create(:user, :customer) }
  let(:menu) { create(:menu, stylist: stylist) }

  def setup_working_hour(start_time: '09:00', end_time: '17:00')
    create(:working_hour,
      stylist: stylist,
      day_of_week: Date.current.wday,
      start_time: Time.zone.parse(start_time),
      end_time: Time.zone.parse(end_time))
  end

  before do
    working_hour = setup_working_hour
    allow(stylist).to receive(:working_hour_for_target_date)
      .with(Date.current).and_return(working_hour)

    fake_relation = instance_double(ActiveRecord::Relation)
    allow(stylist).to receive(:reservation_limits).and_return(fake_relation)
    allow(fake_relation).to receive(:find_by)
      .and_return(instance_double(ReservationLimit, max_reservations: 1))
  end

  describe 'associations' do
    let(:reservation) do
      create(:reservation, customer: customer, stylist: stylist,
        start_date_str: Date.current.to_s, start_time_str: '10:00')
    end
    let(:reservation_menu_selection) { create(:reservation_menu_selection, reservation: reservation, menu: menu) }

    it 'belongs to a menu' do
      expect(reservation_menu_selection.menu).to eq(menu)
    end

    it 'belongs to a reservation' do
      expect(reservation_menu_selection.reservation).to eq(reservation)
    end
  end
end
