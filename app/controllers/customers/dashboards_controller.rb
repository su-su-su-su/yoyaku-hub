# frozen_string_literal: true

module Customers
  class DashboardsController < Customers::ApplicationController
    before_action :ensure_customer_role

    def show; end
  end
end
