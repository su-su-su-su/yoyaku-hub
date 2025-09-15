# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
RSpec.describe Reservation do
  describe 'デモユーザー制限のバリデーション' do
    let(:demo_customer) do
      create(:user,
        email: 'demo_customer_session123@example.com',
        role: 'customer',
        family_name: 'デモ',
        given_name: 'カスタマー')
    end

    let(:demo_stylist) do
      stylist = create(:user,
        email: 'demo_stylist_session123@example.com',
        role: 'stylist',
        family_name: 'デモ',
        given_name: 'スタイリスト')
      setup_stylist_data(stylist)
      stylist
    end

    let(:demo_stylist_different) do
      stylist = create(:user,
        email: 'demo_stylist_different456@example.com',
        role: 'stylist',
        family_name: 'デモ',
        given_name: 'スタイリスト2')
      setup_stylist_data(stylist)
      stylist
    end

    let(:regular_customer) { create(:user, role: 'customer') }
    let(:regular_stylist) do
      stylist = create(:user, role: 'stylist')
      setup_stylist_data(stylist)
      stylist
    end

    let(:future_date) do
      date = 3.days.from_now
      date += 1.day while User::WEEKEND_DAYS.include?(date.wday)
      date
    end

    describe '#validate_demo_user_restrictions' do
      context 'デモカスタマーが予約する場合' do
        it '同じセッションのデモスタイリストには予約可能' do
          reservation = build(:reservation,
            customer: demo_customer,
            stylist: demo_stylist,
            start_at: future_date.beginning_of_day + 14.hours,
            menus: [demo_stylist.menus.first])

          expect(reservation).to be_valid
        end

        it '異なるセッションのデモスタイリストには予約不可' do
          reservation = build(:reservation,
            customer: demo_customer,
            stylist: demo_stylist_different,
            start_at: future_date.beginning_of_day + 14.hours,
            menus: [demo_stylist_different.menus.first])

          expect(reservation).not_to be_valid
          expect(reservation.errors[:base]).to include('デモ環境では指定されたスタイリストのみご利用いただけます。')
        end

        it '通常のスタイリストには予約不可' do
          reservation = build(:reservation,
            customer: demo_customer,
            stylist: regular_stylist,
            start_at: future_date.beginning_of_day + 14.hours,
            menus: [regular_stylist.menus.first])

          expect(reservation).not_to be_valid
          expect(reservation.errors[:base]).to include('デモ環境では指定されたスタイリストのみご利用いただけます。')
        end
      end

      context '通常のカスタマーが予約する場合' do
        it 'どのスタイリストにも予約可能' do
          reservation1 = build(:reservation,
            customer: regular_customer,
            stylist: regular_stylist,
            start_at: future_date.beginning_of_day + 14.hours,
            menus: [regular_stylist.menus.first])
          expect(reservation1).to be_valid

          reservation2 = build(:reservation,
            customer: regular_customer,
            stylist: demo_stylist,
            start_at: future_date.beginning_of_day + 15.hours,
            menus: [demo_stylist.menus.first])
          expect(reservation2).to be_valid
        end
      end
    end

    private

    # rubocop:disable Metrics/MethodLength
    def setup_stylist_data(stylist)
      create(:menu, stylist: stylist, name: 'カット', price: 4000, duration: 60)

      (1..5).each do |wday|
        create(:working_hour,
          stylist: stylist,
          day_of_week: wday,
          start_time: '09:00',
          end_time: '18:00')
      end

      create(:reservation_limit, stylist: stylist, max_reservations: 2)

      create(:working_hour,
        stylist: stylist,
        target_date: future_date,
        start_time: '09:00',
        end_time: '18:00')

      create(:reservation_limit,
        stylist: stylist,
        target_date: future_date,
        max_reservations: 2)

      (18...36).each do |slot|
        create(:reservation_limit,
          stylist: stylist,
          target_date: future_date,
          time_slot: slot,
          max_reservations: 1)
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
# rubocop:enable Metrics/BlockLength, RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups, RSpec/ContextWording
