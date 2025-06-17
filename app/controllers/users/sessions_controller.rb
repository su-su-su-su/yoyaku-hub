# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    def create
      super do |resource|
        redirect_path = after_sign_in_path_for(resource)

        flash[:notice] = I18n.t('devise.sessions.signed_in')

        redirect_to redirect_path, status: :see_other and return
      end
    end
  end
end
