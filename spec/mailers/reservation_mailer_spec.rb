# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReservationMailer do
  let(:stylist) do
    create(:user, role: :stylist,
      family_name: '田中',
      given_name: '太郎',
      email: 'stylist@example.com')
  end

  let(:customer) do
    create(:user, role: :customer,
      family_name: '山田',
      given_name: '花子',
      email: 'customer@example.com')
  end

  let(:menu) { create(:menu, stylist: stylist, name: 'カット', price: 3000, duration: 60) }
  let(:reservation_date) { Time.zone.today + 1.day }
  let(:start_time) { Time.zone.parse("#{reservation_date} 13:00") }
  let(:end_time) { start_time + menu.duration.minutes }

  let(:reservation) do
    Reservation.new(
      customer: customer,
      stylist: stylist,
      start_at: start_time,
      end_at: end_time,
      status: :before_visit
    ).tap do |r|
      r.menu_ids = [menu.id]
      r.save!(validate: false)
    end
  end

  before do
    # 営業時間の設定
    (0..6).each do |day|
      create(:working_hour,
        stylist: stylist,
        day_of_week: day,
        start_time: Time.zone.parse('09:00'),
        end_time: Time.zone.parse('19:00'))
    end

    # 受付可能数の設定
    create(:reservation_limit,
      stylist: stylist,
      target_date: reservation_date,
      time_slot: nil,
      max_reservations: 2)

    (18..38).each do |slot|
      create(:reservation_limit,
        stylist: stylist,
        target_date: reservation_date,
        time_slot: slot,
        max_reservations: 2)
    end

    # 営業日として設定
    create(:holiday,
      stylist: stylist,
      target_date: reservation_date,
      is_holiday: false)
  end

  describe '#reservation_confirmation' do
    let(:mailer) { described_class.new }

    it 'sends confirmation email to customer' do
      expect_any_instance_of(SendgridService).to receive(:send_email).and_return({ success: true })

      mailer.reservation_confirmation(reservation)
    end

    it 'includes correct recipient email' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: customer.email)
      ).and_return({ success: true })

      mailer.reservation_confirmation(reservation)
    end

    it 'includes reservation date in subject' do
      wday = %w[日 月 火 水 木 金 土][reservation_date.wday]
      expected_subject = "【YOYAKU HUB】#{reservation_date.strftime('%m月%d日')}(#{wday}) 13:00のご予約を承りました"

      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(subject: expected_subject)
      ).and_return({ success: true })

      mailer.reservation_confirmation(reservation)
    end

    it 'includes customer name in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('山田 花子')
        expect(args[:text_content]).to include('山田 花子')
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end

    it 'includes stylist name in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('田中 太郎')
        expect(args[:text_content]).to include('田中 太郎')
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end

    it 'includes menu name in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('カット')
        expect(args[:text_content]).to include('カット')
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end

    it 'includes total price in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('¥3,000')
        expect(args[:text_content]).to include('¥3,000')
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end

    it 'includes reservation detail URL' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include("/customers/reservations/#{reservation.id}")
        expect(args[:text_content]).to include("/customers/reservations/#{reservation.id}")
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end
  end

  describe '#new_reservation_notification' do
    let(:mailer) { described_class.new }

    it 'sends notification email to stylist' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: stylist.email)
      ).and_return({ success: true })

      mailer.new_reservation_notification(reservation)
    end

    it 'includes YOYAKU HUB in message' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('YOYAKU HUBから予約が入りました')
        expect(args[:text_content]).to include('YOYAKU HUBから予約が入りました')
        { success: true }
      end

      mailer.new_reservation_notification(reservation)
    end

    it 'includes customer name in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('山田 花子')
        expect(args[:text_content]).to include('山田 花子')
        { success: true }
      end

      mailer.new_reservation_notification(reservation)
    end
  end

  describe '#cancellation_confirmation' do
    let(:mailer) { described_class.new }

    it 'sends cancellation email to customer' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: customer.email)
      ).and_return({ success: true })

      mailer.cancellation_confirmation(reservation)
    end

    it 'includes rebooking URL in email content' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include("/customers/stylists/#{stylist.id}/menus")
        expect(args[:text_content]).to include("/customers/stylists/#{stylist.id}/menus")
        { success: true }
      end

      mailer.cancellation_confirmation(reservation)
    end

    it 'includes menu names only without price and duration' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('カット')
        expect(args[:html_content]).not_to match(/カット.*60分.*¥3,000/)
        { success: true }
      end

      mailer.cancellation_confirmation(reservation)
    end
  end

  describe '#cancellation_notification' do
    let(:mailer) { described_class.new }

    it 'sends cancellation notification to stylist' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: stylist.email)
      ).and_return({ success: true })

      mailer.cancellation_notification(reservation)
    end

    it 'includes cancellation message' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('予約がキャンセルされました')
        expect(args[:text_content]).to include('予約がキャンセルされました')
        { success: true }
      end

      mailer.cancellation_notification(reservation)
    end
  end

  describe '#reservation_updated_notification' do
    let(:mailer) { described_class.new }
    let(:changes) { { start_at: { from: '10:00', to: '13:00' } } }

    it 'sends update notification to customer' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: customer.email)
      ).and_return({ success: true })

      mailer.reservation_updated_notification(reservation, changes)
    end

    it 'includes update message' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('予約内容が以下のように変更されました')
        expect(args[:text_content]).to include('予約内容が以下のように変更されました')
        { success: true }
      end

      mailer.reservation_updated_notification(reservation, changes)
    end

    it 'includes reservation detail URL' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include("/customers/reservations/#{reservation.id}")
        expect(args[:text_content]).to include("/customers/reservations/#{reservation.id}")
        { success: true }
      end

      mailer.reservation_updated_notification(reservation, changes)
    end
  end

  describe '#reservation_canceled_by_stylist' do
    let(:mailer) { described_class.new }

    it 'sends cancellation email to customer' do
      expect_any_instance_of(SendgridService).to receive(:send_email).with(
        hash_including(to: customer.email)
      ).and_return({ success: true })

      mailer.reservation_canceled_by_stylist(reservation)
    end

    it 'includes apology message' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('スタイリストにより')
        expect(args[:html_content]).to include('キャンセルさせていただきました')
        { success: true }
      end

      mailer.reservation_canceled_by_stylist(reservation)
    end

    it 'includes rebooking button' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        expect(args[:html_content]).to include('別の日時で予約する')
        expect(args[:html_content]).to include("/customers/stylists/#{stylist.id}/menus")
        { success: true }
      end

      mailer.reservation_canceled_by_stylist(reservation)
    end
  end

  describe 'date formatting' do
    let(:mailer) { described_class.new }

    it 'formats date with Japanese weekday' do
      expect_any_instance_of(SendgridService).to receive(:send_email) do |_, args|
        wday = %w[日 月 火 水 木 金 土][reservation_date.wday]
        expected_format = "#{reservation_date.year}年#{reservation_date.month}月#{reservation_date.day}日(#{wday})"
        expect(args[:html_content]).to include(expected_format)
        { success: true }
      end

      mailer.reservation_confirmation(reservation)
    end
  end
end
