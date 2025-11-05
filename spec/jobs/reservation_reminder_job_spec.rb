# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers, RSpec/AnyInstance, RSpec/LetSetup
RSpec.describe ReservationReminderJob do
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

  let(:demo_customer) do
    create(:user, role: :customer,
      family_name: 'デモ',
      given_name: 'カスタマー',
      email: 'demo_customer_test123@example.com')
  end

  let(:menu) { create(:menu, stylist: stylist, name: 'カット', price: 3000, duration: 60) }
  let(:tomorrow) { Date.tomorrow }
  let(:start_time) { Time.zone.parse("#{tomorrow} 14:00") }

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
      target_date: tomorrow,
      time_slot: nil,
      max_reservations: 2)

    (18..38).each do |slot|
      create(:reservation_limit,
        stylist: stylist,
        target_date: tomorrow,
        time_slot: slot,
        max_reservations: 2)
    end
  end

  describe '#perform' do
    context '前日以前に作成された明日の予約がある場合' do
      let!(:target_reservation) do
        Reservation.new(
          customer: customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :before_visit,
          created_at: 2.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it 'リマインダーメールが送信される' do
        expect_any_instance_of(ReservationMailer).to receive(:reminder_email).with(target_reservation).and_call_original
        allow_any_instance_of(SendgridService).to receive(:send_email).and_return({ success: true })

        described_class.perform_now
      end

      it '正常に処理が完了する' do
        allow_any_instance_of(SendgridService).to receive(:send_email).and_return({ success: true })
        allow_any_instance_of(ReservationMailer).to receive(:reminder_email).and_call_original

        expect { described_class.perform_now }.not_to raise_error
      end
    end

    context '当日に作成された明日の予約がある場合' do
      let!(:same_day_reservation) do
        Reservation.new(
          customer: customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :before_visit,
          created_at: Time.current
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it 'リマインダーメールは送信されない' do
        expect_any_instance_of(ReservationMailer).not_to receive(:reminder_email)

        described_class.perform_now
      end
    end

    context 'デモユーザーの予約がある場合' do
      let!(:demo_reservation) do
        Reservation.new(
          customer: demo_customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :before_visit,
          created_at: 2.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it 'リマインダーメールは送信されない' do
        expect_any_instance_of(SendgridService).not_to receive(:send_email)

        described_class.perform_now
      end
    end

    context 'キャンセル済みの予約がある場合' do
      let!(:canceled_reservation) do
        Reservation.new(
          customer: customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :canceled,
          created_at: 2.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it 'リマインダーメールは送信されない' do
        expect_any_instance_of(ReservationMailer).not_to receive(:reminder_email)

        described_class.perform_now
      end
    end

    context '複数の対象予約がある場合' do
      let!(:reservation1) do
        Reservation.new(
          customer: customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :before_visit,
          created_at: 2.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      let(:customer2) do
        create(:user, role: :customer,
          family_name: '佐藤',
          given_name: '次郎',
          email: 'customer2@example.com')
      end

      let!(:reservation2) do
        Reservation.new(
          customer: customer2,
          stylist: stylist,
          start_at: start_time + 2.hours,
          end_at: start_time + 3.hours,
          status: :before_visit,
          created_at: 3.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it '全ての対象予約にリマインダーメールが送信される' do
        # SendgridServiceのモックを設定
        send_email_count = 0
        allow_any_instance_of(SendgridService).to receive(:send_email) do
          send_email_count += 1
          { success: true }
        end

        described_class.perform_now

        # 2つの予約に対して送信されたことを確認
        expect(send_email_count).to eq(2)
      end
    end

    context 'メール送信でエラーが発生した場合' do
      let!(:target_reservation) do
        Reservation.new(
          customer: customer,
          stylist: stylist,
          start_at: start_time,
          end_at: start_time + 60.minutes,
          status: :before_visit,
          created_at: 2.days.ago
        ).tap do |r|
          r.menu_ids = [menu.id]
          r.save!(validate: false)
        end
      end

      it 'エラーログが記録され、処理は継続される' do
        allow_any_instance_of(ReservationMailer).to receive(:reminder_email).and_raise(StandardError, 'Test error')

        allow(Rails.logger).to receive(:error)

        expect { described_class.perform_now }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(/リマインダーメール送信失敗/)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers, RSpec/AnyInstance, RSpec/LetSetup
