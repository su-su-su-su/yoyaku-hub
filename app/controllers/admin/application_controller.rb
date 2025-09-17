# frozen_string_literal: true

module Admin
  class ApplicationController < ::ApplicationController
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      # ログインしていない場合はログインページへ
      unless user_signed_in?
        redirect_to new_user_session_path, alert: I18n.t('flash.admin.users.login_required')
        return
      end

      # ログインしているが管理者でない場合
      return if current_user.admin? && current_user.active?

      redirect_to root_path, alert: I18n.t('flash.admin.users.access_denied')
      nil
    end
  end
end
