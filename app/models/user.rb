# frozen_string_literal: true

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

  KATAKANA_REGEX = /\A[ァ-ヶー]+\z/

  validates :family_name_kana, format: {
    with: KATAKANA_REGEX,
    message: I18n.t('errors.messages.only_katakana')
  }, allow_blank: true

  validates :given_name_kana, format: {
    with: KATAKANA_REGEX,
    message: I18n.t('errors.messages.only_katakana')
  }, allow_blank: true

  validates :family_name, :given_name, presence: true, if: :profile_validation_required?
  validates :family_name_kana, :given_name_kana, presence: true, if: :profile_validation_required?
  validates :gender, :date_of_birth, presence: true, if: :profile_validation_required?
  attr_accessor :validating_profile

  enum :role, { customer: 0, stylist: 1 }
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :omniauthable, omniauth_providers: [:google_oauth2]

  def self.from_omniauth(auth, role_for_new_user = nil)
    user = find_by(provider: auth.provider, uid: auth.uid)

    return update_existing_user_with_omniauth(user, auth) if user

    return nil if role_for_new_user.blank?

    build_new_user_with_omniauth(auth, role_for_new_user)
  end

  def min_active_menu_duration
    menus.where(is_active: true).minimum(:duration) || 0
  end

  def profile_validation_required?
    persisted? || validating_profile == true
  end

  def profile_complete?
    family_name.present? && given_name.present? &&
      family_name_kana.present? && given_name_kana.present? &&
      gender.present? && date_of_birth.present?
  end

  def trying_to_complete_profile?
    validating_profile == true
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

  def self.update_existing_user_with_omniauth(user, auth)
    user.email = auth.info.email

    user.family_name = auth.info.last_name if auth.info.last_name.present? && user.family_name.blank?

    user.given_name = auth.info.first_name if auth.info.first_name.present? && user.given_name.blank?

    user.save if user.changed?
    user
  end

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
end
