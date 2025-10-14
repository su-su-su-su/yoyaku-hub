# frozen_string_literal: true

module Stylists
  class ReservationsController < Stylists::ApplicationController
    before_action :set_reservation, only: %i[show edit update cancel]
    before_action :load_time_options, only: %i[edit update]
    before_action :load_active_menus, only: %i[edit update]

    def show; end

    def cancel
      @reservation.canceled!
      send_cancellation_notification_to_customer(@reservation)
      redirect_with_toast stylists_schedules_path(date: @reservation.start_at.to_date),
        t('stylists.reservations.cancelled'), type: :success
    end

    def edit; end

    def update
      # 変更前の状態を記録
      original_start_at = @reservation.start_at
      original_menu_ids = @reservation.menu_ids.sort

      if @reservation.update(reservation_params)
        # 変更内容を検出
        changes = detect_reservation_changes(original_start_at, original_menu_ids)

        # 変更があった場合はメール送信
        send_update_notification_to_customer(@reservation, changes) if changes.any?

        redirect_with_toast stylists_reservation_path(date: @reservation.start_at.to_date),
          t('stylists.reservations.updated'), type: :success
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def update_time_options
      reservation_date = Reservation.safe_parse_date(
        params[:start_date_str],
        default: Time.zone.today
      )

      @time_options = current_user.generate_time_options_for_date(reservation_date)

      render partial: 'time_select', locals: { f: nil, time_options: @time_options, selected_time: nil }
    end

    private

    def set_reservation
      @reservation = current_user.stylist_reservations.find(params[:id])
    end

    def reservation_params
      params.require(:reservation).permit(:start_date_str, :start_time_str, :custom_duration, menu_ids: [])
    end

    def load_time_options
      reservation_date = Reservation.safe_parse_date(
        params.dig(:reservation, :start_date_str),
        default: @reservation&.start_at&.to_date || Time.zone.today
      )

      @time_options = current_user.generate_time_options_for_date(reservation_date)
    end

    def load_active_menus
      @active_menus = current_user.menus.where(is_active: true)
    end

    def send_cancellation_notification_to_customer(reservation)
      mailer = ReservationMailer.new
      result = mailer.reservation_canceled_by_stylist(reservation)

      if result[:success]
        Rails.logger.info "顧客への予約キャンセル通知メール送信成功: Reservation ##{reservation.id}"
      else
        Rails.logger.error "顧客への予約キャンセル通知メール送信失敗: Reservation ##{reservation.id}, Error: #{result[:error]}"
      end
    rescue StandardError => e
      Rails.logger.error "顧客への通知メール送信中にエラーが発生: #{e.message}"
    end

    def detect_reservation_changes(original_start_at, original_menu_ids)
      changes = {}

      # 日時の変更をチェック
      if @reservation.start_at != original_start_at
        changes[:start_at] = {
          from: original_start_at,
          to: @reservation.start_at
        }
      end

      # メニューの変更をチェック
      current_menu_ids = @reservation.menu_ids.sort
      if current_menu_ids != original_menu_ids
        changes[:menus] = {
          from: original_menu_ids,
          to: current_menu_ids
        }
      end

      changes
    end

    def send_update_notification_to_customer(reservation, changes)
      mailer = ReservationMailer.new
      result = mailer.reservation_updated_notification(reservation, changes)

      if result[:success]
        Rails.logger.info "顧客への予約変更通知メール送信成功: Reservation ##{reservation.id}"
        Rails.logger.info "変更内容: #{changes.inspect}"
      else
        Rails.logger.error "顧客への予約変更通知メール送信失敗: Reservation ##{reservation.id}, Error: #{result[:error]}"
      end
    rescue StandardError => e
      Rails.logger.error "顧客への変更通知メール送信中にエラーが発生: #{e.message}"
    end
  end
end
