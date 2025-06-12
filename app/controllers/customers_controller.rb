# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customer_role

  def show; end

end
