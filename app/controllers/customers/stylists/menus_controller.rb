# frozen_string_literal: true

module Customers
  module Stylists
    class MenusController < ApplicationController
      def index
        @stylist = User.find(params[:stylist_id])
        @menus = @stylist.menus.where(is_active: true)
      end
    end
  end
end
