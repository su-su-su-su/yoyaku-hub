# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: [:google_oauth2]

    def google_oauth2
      auth = request.env['omniauth.auth']
      role = session.delete(:role) || 'customer'

      @user = User.from_omniauth(auth, role)

      if @user.persisted?
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
      else
        session['devise.google_data'] = auth.except(:extra)
        redirect_to new_user_registration_url
      end
    end
  end
end
