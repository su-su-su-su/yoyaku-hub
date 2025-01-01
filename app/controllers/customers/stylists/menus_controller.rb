# frozen_string_literal: true

module Customers
  module Stylists
    class MenusController < ApplicationController
      def index
        @stylist = User.find(params[:stylist_id])
        @menus = @stylist.menus
      end
    end
  end
end
