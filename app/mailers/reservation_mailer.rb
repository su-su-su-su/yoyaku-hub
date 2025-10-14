# frozen_string_literal: true

class ReservationMailer < ApplicationMailer
  # カスタマーが予約を登録した時の確認メール
  def reservation_confirmation(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    mail(
      to: @customer.email,
      subject: "【予約確認】#{format_date(@reservation.start_at)}のご予約を承りました"
    )
  end

  # カスタマーが予約をキャンセルした時の確認メール
  def cancellation_confirmation(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist

    mail(
      to: @customer.email,
      subject: "【予約キャンセル】ご予約をキャンセルしました"
    )
  end

  # 美容師への新規予約通知
  def new_reservation_notification(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    mail(
      to: @stylist.email,
      subject: "【新規予約】#{format_date(@reservation.start_at)}に予約が入りました"
    )
  end

  # 美容師への予約キャンセル通知
  def cancellation_notification(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist

    mail(
      to: @stylist.email,
      subject: "【予約キャンセル】#{format_date(@reservation.start_at)}の予約がキャンセルされました"
    )
  end

  # 美容師が予約を変更した時のカスタマーへの通知
  def reservation_updated_notification(reservation, changes = {})
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus
    @changes = changes

    mail(
      to: @customer.email,
      subject: "【予約変更】ご予約内容が変更されました"
    )
  end

  # 美容師が予約をキャンセルした時のカスタマーへの通知
  def reservation_canceled_by_stylist(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist

    mail(
      to: @customer.email,
      subject: "【重要】ご予約がキャンセルされました"
    )
  end

  private

  def format_date(datetime)
    datetime.strftime('%m月%d日(%a) %H:%M')
  end
end