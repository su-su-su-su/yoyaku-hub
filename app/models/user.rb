# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  has_many :menus, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :working_hours, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :holidays, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :reservation_limits, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :reservations, class_name: 'Reservation', foreign_key: :customer_id, inverse_of: :customer,
    dependent: :destroy
  has_many :stylist_reservations, class_name: 'Reservation', foreign_key: :stylist_id, inverse_of: :stylist,
    dependent: :destroy
  has_many :stylist_chartes, class_name: 'Charte', foreign_key: :stylist_id, inverse_of: :stylist,
    dependent: :destroy
  has_many :customer_chartes, class_name: 'Charte', foreign_key: :customer_id, inverse_of: :customer,
    dependent: :destroy
  has_many :products, dependent: :destroy

  KATAKANA_REGEX = /\A[ァ-ヶー]+\z/

  WEEKEND_DAYS = [0, 6].freeze

  validates :family_name_kana, format: {
    with: KATAKANA_REGEX,
    message: I18n.t('errors.messages.only_katakana')
  }, allow_blank: true

  validates :given_name_kana, format: {
    with: KATAKANA_REGEX,
    message: I18n.t('errors.messages.only_katakana')
  }, allow_blank: true

  validates :family_name, :given_name, presence: true, if: :name_validation_required?
  validates :family_name_kana, :given_name_kana, presence: true, if: :name_validation_required?
  validates :gender, presence: true, if: :gender_validation_required?
  validates :date_of_birth, presence: true, if: :date_of_birth_validation_required?

  enum :role, { customer: 0, stylist: 1, admin: 2 }
  enum :status, { active: 0, inactive: 1 }

  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :timeoutable,
    :lockable, :omniauthable, omniauth_providers: [:google_oauth2]

  # Stripe Customer作成は新規登録フロー内で手動で行うため、after_createコールバックは削除
  # （ユーザーが新規登録後、即座にサブスクリプション登録画面へ遷移してStripe Checkoutを完了する）

  def self.from_omniauth(auth, role_for_new_user = nil)
    user = find_by(provider: auth.provider, uid: auth.uid)

    return update_existing_user_with_omniauth(user, auth) if user

    return nil if role_for_new_user.blank?

    build_new_user_with_omniauth(auth, role_for_new_user)
  end

  def min_active_menu_duration
    menus.where(is_active: true).minimum(:duration) || 0
  end

  # セッションタイムアウト時間を設定
  def timeout_in
    if stylist?
      6.hours
    else
      1.year
    end
  end

  def profile_validation_required?
    persisted? || validation_context == :profile_completion
  end

  def name_validation_required?
    profile_validation_required? || created_by_stylist_id.present?
  end

  def gender_validation_required?
    profile_validation_required?
  end

  def date_of_birth_validation_required?
    return false if created_by_stylist_id.present?

    profile_validation_required?
  end

  def profile_complete?
    family_name.present? && given_name.present? &&
      family_name_kana.present? && given_name_kana.present? &&
      gender.present? && date_of_birth.present?
  end

  def default_shift_settings_configured?
    default_working_hour_exists = working_hours.exists?(target_date: nil)
    default_reservation_limit_exists = reservation_limits.exists?(target_date: nil, time_slot: nil)

    default_working_hour_exists && default_reservation_limit_exists
  end

  def registered_menus?
    menus.exists?
  end

  def current_month_shifts_configured?
    today = Date.current
    start_of_month = today.beginning_of_month
    end_of_month = today.end_of_month
    month_range = start_of_month..end_of_month

    working_hours.exists?(target_date: month_range) ||
      holidays.exists?(target_date: month_range) ||
      reservation_limits.exists?(target_date: month_range)
  end

  def next_month_shifts_configured?
    next_month_date = Date.current.next_month
    start_of_month = next_month_date.beginning_of_month
    end_of_month = next_month_date.end_of_month
    month_range = start_of_month..end_of_month

    working_hours.exists?(target_date: month_range) ||
      holidays.exists?(target_date: month_range) ||
      reservation_limits.exists?(target_date: month_range)
  end

  # rubocop:disable Metrics/AbcSize
  def self.update_existing_user_with_omniauth(user, auth)
    user.email = auth.info.email

    user.family_name = auth.info.last_name if auth.info.last_name.present? && user.family_name.blank?

    user.given_name = auth.info.first_name if auth.info.first_name.present? && user.given_name.blank?

    user.save if user.changed?
    user
  end
  # rubocop:enable Metrics/AbcSize

  def self.build_new_user_with_omniauth(auth, role)
    new_attrs = {
      provider: auth.provider,
      uid: auth.uid,
      email: auth.info.email,
      password: Devise.friendly_token[0, 20],
      role: role,
      family_name: auth.info.last_name,
      given_name: auth.info.first_name
    }
    new(new_attrs)
  end

  def holiday?(date)
    holiday = holidays.find_by(target_date: date)
    return holiday.is_holiday? if holiday.present?

    if HolidayJp.holiday?(date)
      holiday_setting = holidays.find_by(day_of_week: 7, target_date: nil)
      return holiday_setting.is_holiday? if holiday_setting.present?
    end

    weekday_holiday = holidays.find_by(day_of_week: date.wday, target_date: nil)
    return true if weekday_holiday.present?

    false
  end

  def reservation_limit_for(date)
    reservation_limit = reservation_limits.find_by(target_date: date)
    return reservation_limit if reservation_limit.present?

    global_limit = reservation_limits.find_by(target_date: nil)
    if global_limit.present?
      return reservation_limits.new(
        target_date: date,
        max_reservations: global_limit.max_reservations,
        time_slot: global_limit.time_slot
      )
    end

    reservation_limits.new(target_date: date, max_reservations: 1)
  end

  def working_hour_for_target_date(date)
    working_hours.find_by(target_date: date)
  end

  def working_hour_for(date)
    working_hour = working_hour_for_target_date(date)
    return working_hour if working_hour.present?

    if HolidayJp.holiday?(date)
      holiday_working_hour = working_hours.find_by(day_of_week: 7, target_date: nil)
      return holiday_working_hour if holiday_working_hour.present?
    end

    wday = date.wday
    default_weekday_working_hour = working_hours.find_by(day_of_week: wday, target_date: nil)
    return default_weekday_working_hour if default_weekday_working_hour.present?

    working_hours.build(
      target_date: date,
      start_time: Time.zone.parse(WorkingHour::DEFAULT_START_TIME),
      end_time: Time.zone.parse(WorkingHour::DEFAULT_END_TIME)
    )
  end

  def generate_time_options_for_date(date)
    working_hour = working_hour_for_target_date(date)

    if working_hour.present?
      start_time = working_hour.start_time
      end_time = working_hour.end_time
    else
      start_time = Time.zone.parse(WorkingHour::DEFAULT_START_TIME)
      end_time = Time.zone.parse(WorkingHour::DEFAULT_END_TIME)
    end

    WorkingHour.generate_time_options_between(start_time, end_time)
  end

  def find_next_reservation_start_slot(date, from_slot)
    working_hour = working_hour_for_target_date(date)
    day_end_slot = if working_hour&.end_time
                     Reservation.to_slot_index(working_hour.end_time)
                   else
                     48
                   end

    day_start = date.beginning_of_day
    day_end   = date.end_of_day

    reservations_in_day = stylist_reservations
      .where(status: %i[before_visit paid])
      .where(start_at: day_start..day_end)

    start_slots = reservations_in_day.map do |res|
      Reservation.to_slot_index(res.start_at)
    end

    next_start_slots = start_slots.select { |slot| slot >= from_slot }
    next_start_slots.min || day_end_slot
  end

  def find_previous_reservation_end_slot(date, from_slot)
    working_hour = working_hour_for_target_date(date)
    day_start_slot = if working_hour&.start_time
                       Reservation.to_slot_index(working_hour.start_time)
                     else
                       0
                     end

    day_start = date.beginning_of_day
    day_end   = date.end_of_day

    reservations_in_day = stylist_reservations
      .where(status: %i[before_visit paid])
      .where(start_at: day_start..day_end)

    end_slots = reservations_in_day.map do |res|
      Reservation.to_slot_index(res.end_at)
    end

    prev_end_slots = end_slots.select { |slot| slot <= from_slot }
    prev_end_slots.max || day_start_slot
  end

  # デフォルトスコープでactiveなユーザーのみ取得
  default_scope { where(status: :active) }

  # 無効化されたユーザーも含めて取得する場合
  scope :with_inactive, -> { unscope(where: :status) }

  scope :customers_for_stylist, lambda { |stylist_id|
    where(role: :customer)
      .where(
        "(created_by_stylist_id = ? OR
          (created_by_stylist_id IS NULL AND id IN
            (SELECT DISTINCT customer_id FROM reservations WHERE stylist_id = ?)))",
        stylist_id, stylist_id
      )
  }

  def self.search_by_name(query)
    return none if query.blank?

    # SQLインジェクション対策: sanitize_sql_likeを使用
    sanitized_query = sanitize_sql_like(query)

    where(
      'family_name ILIKE ? OR given_name ILIKE ? OR ' \
      'family_name_kana ILIKE ? OR given_name_kana ILIKE ? OR ' \
      'email ILIKE ? OR ' \
      'CONCAT(family_name, given_name) ILIKE ? OR ' \
      'CONCAT(family_name_kana, given_name_kana) ILIKE ?',
      "%#{sanitized_query}%", "%#{sanitized_query}%", "%#{sanitized_query}%", "%#{sanitized_query}%",
      "%#{sanitized_query}%", "%#{sanitized_query}%", "%#{sanitized_query}%"
    )
  end

  def age
    return nil unless date_of_birth

    today = Date.current
    age = today.year - date_of_birth.year
    age -= 1 if today < date_of_birth + age.years
    age
  end

  def visit_info_for_stylist(stylist_id)
    completed_reservations = reservations
      .joins(:stylist)
      .where(stylist_id: stylist_id, status: [:paid])
      .order(:start_at)

    {
      first_visit: completed_reservations.first&.start_at&.to_date,
      last_visit: completed_reservations.last&.start_at&.to_date,
      total_visits: completed_reservations.count,
      visit_frequency: calculate_visit_frequency(completed_reservations)
    }
  end

  def dummy_email?
    email&.include?('@no-email-dummy.invalid') || false
  end

  def demo_customer?
    email&.include?('demo_customer_') && email.include?('@example.com')
  end

  def demo_stylist?
    email&.include?('demo_stylist_') && email.include?('@example.com')
  end

  def demo_session_id
    return nil unless demo_customer? || demo_stylist?

    email.split('_')[2].split('@')[0]
  end

  def same_demo_session?(other_user)
    return false unless (demo_customer? || demo_stylist?) && other_user&.demo_user?

    demo_session_id == other_user.demo_session_id
  end

  def demo_user?
    demo_customer? || demo_stylist?
  end

  def self.demo_stylists_for_customer(customer)
    return none unless customer&.demo_customer?

    session_id = customer.demo_session_id
    where(role: :stylist, email: "demo_stylist_#{session_id}@example.com")
  end

  def can_book_with_stylist?(stylist)
    return true unless demo_customer?
    return false unless stylist&.demo_stylist?

    same_demo_session?(stylist)
  end

  class << self
    def find_or_create_demo_stylist(session_id)
      email = "demo_stylist_#{session_id}@example.com"

      stylist = find_by(email: email)
      return stylist if stylist

      # セッションIDとタイムスタンプを使用してユニークなパスワードを生成
      secure_password = SecureRandom.hex(32)

      stylist = create!(
        email: email,
        password: secure_password,
        role: 'stylist',
        family_name: 'デモ',
        given_name: 'スタイリスト',
        family_name_kana: 'デモ',
        given_name_kana: 'スタイリスト',
        gender: 'male',
        date_of_birth: '1990-01-01'
      )

      stylist.setup_demo_data
      stylist
    end

    def find_or_create_demo_customer(session_id)
      email = "demo_customer_#{session_id}@example.com"

      customer = find_by(email: email)
      if customer
        find_or_create_demo_stylist(session_id)
        return customer
      end

      # セッションIDとタイムスタンプを使用してユニークなパスワードを生成
      secure_password = SecureRandom.hex(32)

      customer = create!(
        email: email,
        password: secure_password,
        role: 'customer',
        family_name: 'デモ',
        given_name: 'カスタマー',
        family_name_kana: 'デモ',
        given_name_kana: 'カスタマー',
        gender: 'female',
        date_of_birth: '1995-05-15'
      )

      find_or_create_demo_stylist(session_id)

      customer
    end
  end

  def setup_demo_data
    return unless demo_stylist?

    setup_demo_menus
    setup_demo_working_hours
    setup_demo_holidays
    setup_demo_reservation_limits
    setup_demo_monthly_shifts
    create_demo_reservation
  end

  # サブスクリプション関連メソッド
  def subscription_active?
    return true if trial_active?
    return false if subscription_status.blank?

    %w[active trialing].include?(subscription_status)
  end

  def trial_active?
    return false if trial_ends_at.blank?

    trial_ends_at > Time.current
  end

  def needs_subscription?
    return false unless stylist? # Stylistのみ課金対象
    return false if subscription_exempt? # サブスク免除（モニター等）
    return false if trial_active?

    !subscription_active?
  end

  def trial_days_remaining
    return 0 if trial_ends_at.blank? || trial_ends_at <= Time.current

    ((trial_ends_at - Time.current) / 1.day).ceil
  end

  # Stripe Checkout完了済みかどうか（subscription_idまたはtrial_ends_atがあればOK）
  def stripe_setup_complete?
    stripe_subscription_id.present? || trial_ends_at.present?
  end

  # 退会処理（アカウント無効化 + Stripeサブスクリプション解約）
  def deactivate_account!
    transaction do
      # 1. Stripeのサブスクリプションを即座に解約
      cancel_stripe_subscription if stripe_subscription_id.present?

      # 2. ユーザーを無効化
      update!(status: :inactive)
    end
  end

  private

  def should_create_stripe_customer?
    # デモユーザーとダミーメールユーザーは除外
    return false if demo_user?
    return false if dummy_email?
    return false if subscription_exempt? # サブスク免除（モニター等）は除外

    # Stylistのみ Stripe Customer を作成する（課金対象）
    # Admin と Customer は課金対象外
    stylist?
  end

  def create_stripe_customer
    return if stripe_customer_id.present?
    return if Rails.configuration.stripe[:secret_key].blank?

    begin
      customer = Stripe::Customer.create(
        email: email,
        metadata: {
          user_id: id,
          role: role
        }
      )

      # Stripe APIの結果を確実に保存するため、意図的にupdate_columnsを使用
      # バリデーション・コールバックは不要（システム内部処理のため）
      # rubocop:disable Rails/SkipsModelValidations
      update_columns(
        stripe_customer_id: customer.id,
        trial_ends_at: 6.months.from_now,
        trial_used: true
      )
      # rubocop:enable Rails/SkipsModelValidations
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe Customer作成エラー: #{e.message}"
      # エラーが発生してもユーザー作成は継続
    end
  end

  def cancel_stripe_subscription
    return if stripe_subscription_id.blank?
    return if Rails.configuration.stripe[:secret_key].blank?

    Stripe::Subscription.cancel(stripe_subscription_id)
    Rails.logger.info "退会処理: Stripeサブスクリプション解約 User ##{id}"
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe解約エラー (User ##{id}): #{e.message}"
    raise # エラーの場合はロールバック
  end

  def setup_demo_menus
    return unless menus.empty?

    menus.create!([
                    { name: 'カット', price: 4000, duration: 60, is_active: true },
                    { name: 'カラーリング', price: 6000, duration: 90, is_active: true },
                    { name: 'パーマ', price: 7000, duration: 120, is_active: true }
                  ])
  end

  def setup_demo_working_hours
    return unless working_hours.where(target_date: nil).empty?

    (1..5).each do |wday|
      working_hours.create!(
        day_of_week: wday,
        start_time: '09:00',
        end_time: '18:00'
      )
    end
  end

  def setup_demo_holidays
    return unless holidays.where(target_date: nil).empty?

    [0, 6].each do |wday|
      holidays.create!(
        day_of_week: wday,
        is_holiday: true
      )
    end
  end

  def setup_demo_reservation_limits
    return unless reservation_limits.where(target_date: nil).empty?

    reservation_limits.create!(max_reservations: 1)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def setup_demo_monthly_shifts
    today = Date.current
    # rubocop:disable Metrics/BlockLength
    [today.beginning_of_month, today.next_month.beginning_of_month].each do |month_start|
      (month_start..month_start.end_of_month).each do |date|
        next if WEEKEND_DAYS.include?(date.wday)

        working_hours.find_or_create_by!(target_date: date) do |wh|
          wh.start_time = '09:00'
          wh.end_time = '18:00'
        end

        next if reservation_limits.exists?(target_date: date)

        reservation_limits.create!(
          target_date: date,
          time_slot: nil,
          max_reservations: 2
        )

        start_slot = 18  # 9:00
        end_slot = 36    # 18:00
        limits_data = (start_slot...end_slot).map do |slot|
          {
            stylist_id: id,
            target_date: date,
            time_slot: slot,
            max_reservations: 1,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        # デモデータの一括作成のため、意図的にinsert_allを使用（パフォーマンス最適化）
        # rubocop:disable Rails/SkipsModelValidations
        ReservationLimit.insert_all(limits_data)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
  def create_demo_reservation
    session_id = demo_session_id
    customer = User.find_or_create_demo_customer(session_id)

    future_date = 3.days.from_now.to_date
    future_date += 1.day while WEEKEND_DAYS.include?(future_date.wday)

    return if stylist_reservations.exists?(customer: customer)

    menu_ids = menus.where(name: 'カット').pluck(:id)
    return if menu_ids.empty?

    reservation = Reservation.new(
      customer: customer,
      stylist: self,
      start_date_str: future_date.strftime('%Y-%m-%d'),
      start_time_str: '14:00',
      status: 'before_visit'
    )
    reservation.menu_ids = menu_ids

    if reservation.save
      Rails.logger.info "デモ予約を作成しました: #{future_date} 14:00 (#{email} → #{customer.email})"
    else
      Rails.logger.error "デモ予約の作成に失敗しました: #{reservation.errors.full_messages.join(', ')}"
    end
  end
  # rubocop:enable Metrics/AbcSize

  def calculate_visit_frequency(reservations)
    return nil if reservations.count < 2

    first_visit = reservations.first.start_at.to_date
    last_visit = reservations.last.start_at.to_date
    total_days = (last_visit - first_visit).to_i
    visits = reservations.count

    return nil if total_days <= 0

    frequency_days = (total_days.to_f / (visits - 1)).round
    "#{frequency_days}日"
  end
end
# rubocop:enable Metrics/ClassLength
