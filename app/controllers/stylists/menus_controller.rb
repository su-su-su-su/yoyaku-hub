# frozen_string_literal: true

module Stylists
  class MenusController < ApplicationController
    def index
      @menus = current_user.menus || []
    end

    def new
      @menu = Menu.new
      respond_to do |format|
        format.html
        format.turbo_stream { render partial: 'form', locals: { menu: @menu } }
      end
    end

    def create
      @menu = current_user.menus.new(menu_params)
      @menus = current_user.menus
      if @menu.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to menus_settings_path }
        end
      else
        respond_to do |format|
          format.turbo_stream { redirect_to menus_settings_path, status: :unprocessable_entity } # 失敗時
          format.html { render :new }
        end
      end
    end

    private

    def menu_params
      params.require(:menu).permit(:sort_order, :name, :price, :duration, :description, category: [])
    end
  end
end
