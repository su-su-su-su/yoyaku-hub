# frozen_string_literal: true

module Stylists
  # rubocop:disable Metrics/ClassLength
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

    def export
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      format = params[:format_type] || 'standard'

      start_date = Date.new(@year, @month, 1)
      end_date = start_date.end_of_month

      csv_data = case format
                 when 'moneyforward'
                   generate_moneyforward_csv(start_date, end_date)
                 when 'freee'
                   generate_freee_csv(start_date, end_date)
                 else
                   generate_standard_csv(start_date, end_date)
                 end

      send_data csv_data,
        filename: "sales_#{format}_#{@year}_#{@month}.csv",
        type: 'text/csv'
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

    def generate_standard_csv(start_date, end_date)
      CSV.generate(encoding: Encoding::SJIS, row_sep: "\r\n") do |csv|
        csv << %w[日付 予約ID 顧客名 技術売上 商品売上 合計金額 メニュー カテゴリー]
        fetch_detailed_accountings(start_date, end_date).each do |accounting|
          csv << build_standard_csv_row(accounting)
        end
      end
    end

    def build_standard_csv_row(accounting)
      reservation = accounting.reservation
      customer_name = format_customer_name(reservation.customer)
      service_amount = reservation.menus.sum(&:price)
      product_amount = calc_product_amount(accounting)

      [
        reservation.start_at.strftime('%Y/%m/%d'),
        reservation.id,
        customer_name,
        service_amount,
        product_amount,
        accounting.total_amount,
        reservation.menus.map(&:name).join(', '),
        reservation.menus.flat_map(&:category).compact.uniq.join(', ')
      ]
    end

    def generate_moneyforward_csv(start_date, end_date)
      CSV.generate(encoding: Encoding::SJIS, row_sep: "\r\n") do |csv|
        csv << %w[取引日 摘要 借方勘定科目 借方金額 貸方勘定科目 貸方金額 備考]
        fetch_detailed_accountings(start_date, end_date).each do |accounting|
          process_moneyforward_accounting(csv, accounting)
        end
      end
    end

    def process_moneyforward_accounting(csv, accounting)
      reservation = accounting.reservation
      customer_name = format_customer_name(reservation.customer)
      service_amount = reservation.menus.sum(&:price)
      product_amount = calc_product_amount(accounting)

      accounting.accounting_payments.each do |payment|
        payment_ratio = payment.amount.to_f / accounting.total_amount
        debit_account = determine_debit_account(payment.payment_method)

        row_data = {
          reservation: reservation,
          customer_name: customer_name,
          debit_account: debit_account,
          ratio: payment_ratio
        }

        add_service_row(csv, row_data, service_amount) if service_amount.positive?
        add_product_row(csv, row_data, product_amount, accounting) if product_amount.positive?
      end
    end

    def add_service_row(csv, row_data, amount)
      reservation = row_data[:reservation]
      csv << [
        reservation.start_at.strftime('%Y/%m/%d'),
        row_data[:customer_name],
        row_data[:debit_account],
        (amount * row_data[:ratio]).round,
        '売上高',
        (amount * row_data[:ratio]).round,
        "技術売上 #{reservation.menus.map(&:name).join(', ')} (予約ID: #{reservation.id})"
      ]
    end

    def add_product_row(csv, row_data, amount, accounting)
      reservation = row_data[:reservation]
      product_names = accounting.accounting_products.map { |ap| "#{ap.product.name}×#{ap.quantity}" }.join(', ')
      csv << [
        reservation.start_at.strftime('%Y/%m/%d'),
        row_data[:customer_name],
        row_data[:debit_account],
        (amount * row_data[:ratio]).round,
        '売上高',
        (amount * row_data[:ratio]).round,
        "商品売上 #{product_names} (予約ID: #{reservation.id})"
      ]
    end

    def determine_debit_account(payment_method)
      case payment_method
      when 'cash' then '現金'
      when 'credit_card', 'digital_pay' then '売掛金'
      else 'その他未収入金'
      end
    end

    def generate_freee_csv(start_date, end_date)
      CSV.generate(encoding: Encoding::SJIS, row_sep: "\r\n") do |csv|
        csv << %w[取引日 収支区分 決済状況 取引先 勘定科目 税区分 金額 備考]
        fetch_detailed_accountings(start_date, end_date).each do |accounting|
          process_freee_accounting(csv, accounting)
        end
      end
    end

    def process_freee_accounting(csv, accounting)
      reservation = accounting.reservation
      customer_name = format_customer_name(reservation.customer)
      service_amount = reservation.menus.sum(&:price)
      product_amount = calc_product_amount(accounting)

      add_freee_service_row(csv, reservation, customer_name, service_amount) if service_amount.positive?
      add_freee_product_row(csv, reservation, customer_name, product_amount, accounting) if product_amount.positive?
    end

    def add_freee_service_row(csv, reservation, customer_name, amount)
      csv << build_freee_row(reservation, customer_name, amount,
        "技術売上 #{reservation.menus.map(&:name).join(', ')}")
    end

    def add_freee_product_row(csv, reservation, customer_name, amount, accounting)
      product_names = accounting.accounting_products.map { |ap| "#{ap.product.name}×#{ap.quantity}" }.join(', ')
      csv << build_freee_row(reservation, customer_name, amount, "商品売上 #{product_names}")
    end

    def build_freee_row(reservation, customer_name, amount, description)
      [
        reservation.start_at.strftime('%Y/%m/%d'),
        '収入',
        '完了',
        customer_name,
        '売上高',
        '課税売上10%',
        amount,
        "#{description} (予約ID: #{reservation.id})"
      ]
    end

    def format_customer_name(customer)
      return 'ゲスト' unless customer

      "#{customer.family_name} #{customer.given_name}"
    end

    def calc_product_amount(accounting)
      accounting.accounting_products.sum { |ap| ap.actual_price * ap.quantity }
    end

    def fetch_detailed_accountings(start_date, end_date)
      Accounting
        .includes(
          reservation: %i[customer menus],
          accounting_products: :product,
          accounting_payments: []
        )
        .joins(:reservation)
        .where(reservations: { stylist_id: current_user.id, start_at: start_date..end_date })
        .where(status: :completed)
        .order('reservations.start_at ASC')
    end
  end
  # rubocop:enable Metrics/ClassLength
end
