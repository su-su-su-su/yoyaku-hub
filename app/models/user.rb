# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  has_many :menus, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :working_hours, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :holidays, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :reservation_limits, foreign_key: :stylist_id, dependent: :destroy, inverse_of: :stylist
  has_many :reservations, foreign_key: :customer_id, dependent: :destroy


  enum :role, { customer: 0, stylist: 1 }
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  def self.from_omniauth(auth, role)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.email = auth.info.email
    user.password ||= Devise.friendly_token[0, 20]
    user.role ||= role
    user.family_name = auth.info.last_name if auth.info.last_name
    user.given_name  = auth.info.first_name if auth.info.first_name
    user.provider = auth.provider
    user.uid = auth.uid
    user.save
    user
  end
end
