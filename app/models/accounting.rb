# frozen_string_literal: true

class Accounting < ApplicationRecord
  belongs_to :reservation
  has_many :accounting_payments, dependent: :destroy
  has_many :accounting_products, dependent: :destroy
  has_many :products, through: :accounting_products

  accepts_nested_attributes_for :accounting_payments,
    allow_destroy: true,
    reject_if: :all_blank

  accepts_nested_attributes_for :accounting_products,
    allow_destroy: true,
    reject_if: ->(attributes) { attributes['product_id'].blank? }

  enum :status, { pending: 0, completed: 1 }

  validates :total_amount, presence: true, numericality: { greater_than: 0 }

  def self.create_with_payments(reservation, total_amount, payment_attributes)
    accounting = nil
    transaction do
      accounting = create!(
        reservation: reservation,
        total_amount: total_amount
      )

      accounting.add_payments!(payment_attributes)
      accounting.complete_accounting!
    end
    accounting
  rescue ActiveRecord::RecordInvalid
    accounting ||= new(
      reservation: reservation,
      total_amount: total_amount
    )
    accounting.accounting_payments.build if accounting.accounting_payments.empty?
    accounting
  end

  def update_with_payments(total_amount, payment_attributes)
    transaction do
      update!(total_amount: total_amount)
      accounting_payments.destroy_all
      add_payments!(payment_attributes)
      complete_accounting!
    end
    true
  rescue ActiveRecord::RecordInvalid
    accounting_payments.build if accounting_payments.empty?
    false
  end

  def add_payments!(payment_attributes)
    if payment_attributes.blank?
      errors.add(:base, '支払い情報を入力してください')
      raise ActiveRecord::RecordInvalid, self
    end

    total_payments = 0
    payments_to_create = []

    payment_attributes.each_value do |payment_attr|
      next if payment_attr[:_destroy] == '1' || payment_attr[:amount].blank?

      amount = payment_attr[:amount].to_i
      payment_method = payment_attr[:payment_method]

      validate_payment!(amount, payment_method)

      total_payments += amount
      payments_to_create << { payment_method: payment_method, amount: amount }
    end

    validate_total_payment!(total_payments)

    payments_to_create.each do |payment_attr|
      accounting_payments.create!(payment_attr)
    end
  end

  def complete_accounting!
    completed!
    reservation.paid!
  end

  def save_with_payments_and_products(payment_attributes)
    transaction do
      save!
      add_payments!(payment_attributes)
      complete_accounting!
    end
    true
  rescue ActiveRecord::RecordInvalid
    accounting_payments.build if accounting_payments.empty?
    accounting_products.build if accounting_products.empty?
    false
  end

  def update_with_payments_and_products(params, payment_attributes)
    transaction do
      # 商品データを更新
      if params[:accounting_products_attributes].present?
        update!(params.slice(:total_amount, :accounting_products_attributes))
      else
        update!(params.slice(:total_amount))
      end

      # 支払い方法を更新
      accounting_payments.destroy_all
      add_payments!(payment_attributes)
      complete_accounting!
    end
    true
  rescue ActiveRecord::RecordInvalid
    accounting_payments.build if accounting_payments.empty?
    accounting_products.build if accounting_products.empty?
    false
  end

  def service_amount
    reservation.menus.sum(&:price)
  end

  def product_sales_amount
    accounting_products.sum { |ap| ap.actual_price * ap.quantity }
  end

  def total_with_products
    total_amount
  end

  def sales_breakdown
    {
      service: service_amount,
      products: product_sales_amount,
      total: total_with_products
    }
  end

  private

  def validate_payment!(amount, payment_method)
    if amount <= 0
      errors.add(:base, '支払い金額は0より大きい値を入力してください')
      raise ActiveRecord::RecordInvalid, self
    end

    return if payment_method.present?

    errors.add(:base, '支払い方法を選択してください')
    raise ActiveRecord::RecordInvalid, self
  end

  def validate_total_payment!(total_payments)
    return unless total_payments != total_amount

    errors.add(:base, "支払い合計（¥#{total_payments}）が会計金額（¥#{total_amount}）と一致しません")
    raise ActiveRecord::RecordInvalid, self
  end
end
