# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: [:google_oauth2]

    def google_oauth2
      auth = request.env['omniauth.auth']
      role_from_session = session.delete(:role)
      @user = User.from_omniauth(auth, role_from_session)

      if @user&.persisted?
        handle_successful_authentication
      elsif @user
        process_new_user_registration(@user, auth, role_from_session)
      else
        handle_unregistered_login_attempt(auth)
      end
    end

    def failure
      redirect_to new_user_session_path, alert: I18n.t('alerts.login_failed')
    end

    private

    def process_new_user_registration(user, auth, role_from_session)
      if role_from_session.present?
        if user.save
          handle_successful_authentication
        else
          error_messages = user.errors.full_messages.join(', ')
          session['devise.google_data'] = auth.except(:extra)
          redirect_path = determine_registration_failure_redirect_path(role_from_session)
          alert_message = "#{I18n.t('errors.messages.registration_failed')}: #{error_messages}"
          redirect_to redirect_path, alert: alert_message
        end
      else
        logger.warn "OmniAuth Callback: Attempted to process new user without role. Auth UID: #{auth&.uid}"
        handle_general_omniauth_failure(auth)
      end
    end

    def handle_unregistered_login_attempt(auth)
      session['devise.google_data'] = auth.except(:extra)
      redirect_to new_user_session_path, alert: I18n.t('alerts.omniauth_account_not_found')
    end

    def determine_registration_failure_redirect_path(role)
      if role == 'stylist'
        new_stylist_registration_path
      else
        new_customer_registration_path
      end
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

    def handle_general_omniauth_failure(auth_data)
      session['devise.google_data'] = auth_data.except(:extra) if auth_data
      redirect_to new_user_registration_url, alert: I18n.t('alerts.authentication_failed')
    end
  end
end
