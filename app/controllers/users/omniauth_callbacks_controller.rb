# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token, only: [:google_oauth2]

    def google_oauth2
      auth = request.env['omniauth.auth']
      role = session.delete(:role) || 'customer'
\
      @user = User.find_by(provider: auth.provider, uid: auth.uid)

      if @user
        @user.update_without_password(
          email: auth.info.email,
          family_name: auth.info.last_name,
          given_name: auth.info.first_name
        )
      else
        @user = User.new(
          provider: auth.provider,
          uid: auth.uid,
          email: auth.info.email,
          password: Devise.friendly_token[0, 20],
          role: role,
          family_name: auth.info.last_name,
          given_name: auth.info.first_name
        )
        @user.save
      end

      if @user.persisted?
        sign_in(:user, @user)

        set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?

        if !@user.profile_complete?
          if @user.stylist?
            redirect_to edit_stylists_profile_path
          else
            redirect_to edit_customers_profile_path
          end
        else
          redirect_to after_sign_in_path_for(@user)
        end
      else
        session['devise.google_data'] = auth.except(:extra)
        redirect_to new_user_registration_url, alert: "認証に失敗しました。再度お試しください。"
      end
    end

    def failure
      redirect_to new_user_session_path, alert: "認証に失敗しました。別の方法でログインをお試しください。"
    end
  end
end
