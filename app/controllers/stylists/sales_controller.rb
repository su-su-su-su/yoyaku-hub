# frozen_string_literal: true

module Stylists
  class SalesController < ApplicationController
    def index
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      start_date = Date.new(@year, @month, 1)
      end_date = start_date.end_of_month

      # 月別の売り上げデータを取得
      @monthly_sales = fetch_monthly_sales(start_date, end_date)

      # 日別の売り上げデータを取得（日平均計算用）
      @daily_sales = fetch_daily_sales(start_date, end_date)

      # カテゴリー別の売上を取得
      @category_sales = fetch_category_sales(start_date, end_date)
    end

    private

    def fetch_monthly_sales(start_date, end_date)
      accountings = Accounting
        .joins(:reservation)
        .where(reservations: { stylist_id: current_user.id, start_at: start_date..end_date })
        .where(status: :completed)

      service_amount = calculate_service_amount(accountings)
      count = accountings.count

      {
        total: accountings.sum(:total_amount),
        count: count,
        service_amount: service_amount,
        product_amount: calculate_product_amount(accountings),
        average_service_price: count.positive? ? (service_amount.to_f / count).round : 0
      }
    end

    def fetch_daily_sales(start_date, end_date)
      Accounting
        .joins(:reservation)
        .where(reservations: { stylist_id: current_user.id, start_at: start_date..end_date })
        .where(status: :completed)
        .group('DATE(reservations.start_at)')
        .sum(:total_amount)
        .transform_keys(&:to_date)
        .sort_by { |date, _| date }
        .to_h
    end

    def calculate_service_amount(accountings)
      accountings.includes(reservation: :menus).sum do |accounting|
        accounting.reservation.menus.sum(&:price)
      end
    end

    def calculate_product_amount(accountings)
      accountings.includes(:accounting_products).sum do |accounting|
        accounting.accounting_products.sum { |ap| ap.actual_price * ap.quantity }
      end
    end

    def fetch_category_sales(start_date, end_date)
      category_totals = calculate_category_totals(start_date, end_date)
      total = category_totals.values.sum
      build_category_percentages(category_totals, total)
    end

    def calculate_category_totals(start_date, end_date)
      category_totals = Hash.new(0)

      fetch_completed_reservations(start_date, end_date).each do |reservation|
        aggregate_menu_categories(reservation, category_totals)
      end

      category_totals
    end

    def fetch_completed_reservations(start_date, end_date)
      Reservation
        .includes(:menus)
        .joins(:accounting)
        .where(stylist_id: current_user.id, start_at: start_date..end_date)
        .where(accountings: { status: :completed })
    end

    def aggregate_menu_categories(reservation, category_totals)
      reservation.menus.each do |menu|
        next if menu.category.blank?

        menu.category.each do |cat|
          category_totals[cat] += menu.price
        end
      end
    end

    def build_category_percentages(category_totals, total)
      category_percentages = {}

      category_totals.each do |category, amount|
        percentage = total.positive? ? (amount.to_f / total * 100).round(1) : 0
        category_percentages[category] = {
          amount: amount,
          percentage: percentage
        }
      end

      category_percentages.sort_by { |_, data| -data[:amount] }.to_h
    end
  end
end
