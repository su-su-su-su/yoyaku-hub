# frozen_string_literal: true

module Customers
  class ApplicationController < ::ApplicationController
    before_action :authenticate_user!
  end
end
