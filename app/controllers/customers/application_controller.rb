# frozen_string_literal: true

module Customers
  class ApplicationController < ::ApplicationController
    layout 'customers'
    before_action :authenticate_user!
  end
end
