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

      if user
        user.email = auth.info.email
        user.family_name = auth.info.last_name if auth.info.last_name.present? && user.family_name.blank?
        user.given_name  = auth.info.first_name if auth.info.first_name.present? && user.given_name.blank?

        user.save if user.changed?
        return user
      end

      if role_for_new_user.present?
        new_attrs = {
          provider: auth.provider,
          uid: auth.uid,
          email: auth.info.email,
          password: Devise.friendly_token[0, 20],
          role: role_for_new_user,
          family_name: auth.info.last_name,
          given_name: auth.info.first_name
        }
        user = new(new_attrs)

        return user
      else
        return nil
      end
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
end
