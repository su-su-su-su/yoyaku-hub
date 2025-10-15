# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    def create
      self.resource = warden.authenticate(auth_options)

      if resource
        handle_successful_login
      else
        handle_failed_login
      end
    end

    def destroy
      super do
        flash[:toast] = { message: I18n.t('devise.sessions.signed_out'), type: :info }
      end
    end

    private

    def handle_successful_login
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      flash[:toast] = { message: I18n.t('devise.sessions.signed_in'), type: :success }
      respond_with resource, location: after_sign_in_path_for(resource)
    end

    def handle_failed_login
      error_message = translate_failure_message(warden.message)
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      flash.now[:toast] = { message: error_message, type: :error }
      respond_with(resource) do |format|
        format.html { render :new, status: :unprocessable_entity }
      end
    end

    def translate_failure_message(failure_message)
      if failure_message.is_a?(Symbol)
        I18n.t("devise.failure.#{failure_message}",
          authentication_keys: 'メールアドレス',
          default: I18n.t('devise.failure.invalid', authentication_keys: 'メールアドレス'))
      else
        failure_message || I18n.t('devise.failure.invalid', authentication_keys: 'メールアドレス')
      end
    end
  end
end
