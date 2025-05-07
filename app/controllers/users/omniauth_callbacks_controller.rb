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
      elsif @user && @user.new_record? && role_from_session.present?
        if @user.save
          handle_successful_authentication
        else
          error_messages = @user.errors.full_messages.join(', ')
          session['devise.google_data'] = auth.except(:extra)
          redirect_path = if role_from_session == 'stylist'
                            new_stylist_registration_path
                          else
                            new_customer_registration_path
                          end
          alert_message = "#{I18n.t('errors.messages.registration_failed')}: #{error_messages}"
          redirect_to redirect_path, alert: alert_message
        end
      elsif @user.nil? && role_from_session.nil?
        session['devise.google_data'] = auth.except(:extra)
        redirect_to new_user_session_path, alert: I18n.t('alerts.omniauth_account_not_found')
      else
        handle_failed_authentication(auth)
      end
    end

    def failure
      redirect_to new_user_session_path, alert: I18n.t('alerts.login_failed')
    end

    private

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
