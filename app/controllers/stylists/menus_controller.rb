# frozen_string_literal: true

module Stylists
  class MenusController < ApplicationController
    def index
      @menus = current_user.menus || []
    end

    def new
      @menu = Menu.new
    end
  end
end
