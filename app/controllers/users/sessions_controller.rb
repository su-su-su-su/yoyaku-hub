# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # rubocop:disable Metrics/AbcSize
    def create
      self.resource = warden.authenticate(auth_options)

      if resource
        # ログイン成功
        set_flash_message!(:notice, :signed_in)
        sign_in(resource_name, resource)
        flash[:toast] = { message: I18n.t('devise.sessions.signed_in'), type: :success }
        respond_with resource, location: after_sign_in_path_for(resource)
      else
        # ログイン失敗
        self.resource = resource_class.new(sign_in_params)
        clean_up_passwords(resource)
        flash.now[:toast] = { message: I18n.t('devise.failure.invalid', authentication_keys: 'メールアドレス'), type: :error }
        respond_with(resource) do |format|
          format.html { render :new, status: :unprocessable_entity }
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def destroy
      super do
        flash[:toast] = { message: I18n.t('devise.sessions.signed_out'), type: :info }
      end
    end
  end
end
