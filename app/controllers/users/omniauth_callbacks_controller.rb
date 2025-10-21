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
      redirect_with_toast new_user_session_path, I18n.t('alerts.login_failed'), type: :error
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
          redirect_with_toast redirect_path, alert_message, type: :error
        end
      else
        logger.warn "OmniAuth Callback: Attempted to process new user without role. Auth UID: #{auth&.uid}"
        handle_general_omniauth_failure(auth)
      end
    end

    def handle_unregistered_login_attempt(auth)
      session['devise.google_data'] = auth.except(:extra)
      redirect_with_toast new_user_session_path, I18n.t('alerts.omniauth_account_not_found'), type: :error
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
      flash[:toast] = { message: I18n.t('devise.omniauth_callbacks.success', kind: 'Google'), type: :success }
      redirect_to decide_redirect_path
    end

    def decide_redirect_path
      # スタイリストで、まだStripe Checkoutを完了していない場合は登録画面へ
      return new_subscription_path if @user.stylist? && !@user.stripe_setup_complete?

      # プロフィールが未完成の場合は編集画面へ
      unless @user.profile_complete?
        return @user.stylist? ? edit_stylists_profile_path : edit_customers_profile_path
      end

      # プロフィール完成済みの場合はダッシュボードへ
      after_sign_in_path_for(@user)
    end

    def handle_general_omniauth_failure(auth_data)
      session['devise.google_data'] = auth_data.except(:extra) if auth_data
      redirect_with_toast new_user_registration_url, I18n.t('alerts.authentication_failed'), type: :error
    end
  end
end
