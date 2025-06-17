# frozen_string_literal: true

module Stylists
  class ApplicationController < ::ApplicationController
    layout 'stylists'
    before_action :authenticate_user!
    before_action :ensure_stylist_role
  end
end
