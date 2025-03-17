# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: [:google_oauth2]

    def google_oauth2
      auth = request.env['omniauth.auth']
      role = session.delete(:role) || 'customer'

      @user = find_or_create_user(auth, role)

      if @user.persisted?
        handle_successful_authentication
      else
        handle_failed_authentication(auth)
      end
    end

    def failure
      redirect_to new_user_session_path, alert: I18n.t('alerts.login_failed')
    end

    private

    def find_or_create_user(auth, role)
      user = User.find_by(provider: auth.provider, uid: auth.uid)

      if user
        update_existing_user(user, auth)
      else
        create_new_user(auth, role)
      end
    end

    def update_existing_user(user, auth)
      user.update_without_password(
        email: auth.info.email,
        family_name: auth.info.last_name,
        given_name: auth.info.first_name
      )
      user
    end

    def create_new_user(auth, role)
      user = User.new(
        provider: auth.provider,
        uid: auth.uid,
        email: auth.info.email,
        password: Devise.friendly_token[0, 20],
        role: role,
        family_name: auth.info.last_name,
        given_name: auth.info.first_name
      )
      user.save
      user
    end

    def handle_successful_authentication
      sign_in(:user, @user)
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
      redirect_to decide_redirect_path
    end

    def decide_redirect_path
      if @user.profile_complete?
        after_sign_in_path_for(@user)
      elsif @user.stylist?
        edit_stylists_profile_path
      else
        edit_customers_profile_path
      end
    end

    def handle_failed_authentication(auth)
      session['devise.google_data'] = auth.except(:extra)
      redirect_to new_user_registration_url, alert: I18n.t('alerts.authentication_failed')
    end
  end
end
