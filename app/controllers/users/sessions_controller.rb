# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    def create
      super do |resource|
        redirect_path = after_sign_in_path_for(resource)

        flash[:toast] = { message: I18n.t('devise.sessions.signed_in'), type: :success }

        redirect_to redirect_path, status: :see_other and return
      end
    end

    def destroy
      super do
        flash[:toast] = { message: I18n.t('devise.sessions.signed_out'), type: :info }
      end
    end
  end
end
