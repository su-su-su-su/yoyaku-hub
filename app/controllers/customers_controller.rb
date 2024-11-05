# frozen_string_literal: true

class CustomersController < ApplicationController
  before_action :authenticate_user!
end
