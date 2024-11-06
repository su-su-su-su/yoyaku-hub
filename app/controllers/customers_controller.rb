# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_customer_role

  private

  def ensure_customer_role
    ensure_role('customer')
  end
end
