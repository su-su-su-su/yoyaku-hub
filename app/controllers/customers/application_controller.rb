# frozen_string_literal: true

module Customers
  class ApplicationController < ::ApplicationController
    layout 'customers'
    before_action :store_user_location!, if: :storable_location?
    before_action :authenticate_user!

    private

    # リダイレクト先を保存（GET リクエストかつ、Ajax/Turbo Frame以外）
    def storable_location?
      request.get? &&
        is_navigational_format? &&
        !devise_controller? &&
        !request.xhr? &&
        !turbo_frame_request? &&
        !internal_page?
    end

    # 内部ページ（プロフィール編集、ダッシュボードなど）は保存しない
    def internal_page?
      request.path.in?([
                         edit_customers_profile_path,
                         customers_dashboard_path
                       ])
    end

    # 現在のURLをDeviseのセッションに保存
    def store_user_location!
      store_location_for(:user, request.fullpath)
    end
  end
end
