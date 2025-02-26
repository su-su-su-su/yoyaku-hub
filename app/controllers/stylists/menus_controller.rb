# frozen_string_literal: true

module Stylists
  class MenusController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }

    def index
      @menus = current_user.menus.order(:sort_order) || []
    end

    def new
      @menu = Menu.new
      respond_to do |format|
        format.html
        format.turbo_stream { render partial: 'form', locals: { menu: @menu } }
      end
    end

    def edit
      @menu = current_user.menus.find(params[:id])
    end

    def create
      @menu = current_user.menus.new(menu_params)
      @menus = current_user.menus.order(:sort_order)
      if @menu.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to menus_settings_path }
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @menu = current_user.menus.find(params[:id])
      @menus = current_user.menus.order(:sort_order)

      respond_to do |format|
        if @menu.update(menu_params)
          format.turbo_stream
          format.html { redirect_to menus_settings_path }
        else
          format.html { render :edit, status: :unprocessable_entity }
        end
      end
    end

    private

    def menu_params
      params.require(:menu).permit(:sort_order, :name, :price, :duration, :description, :is_active, category: [])
    end
  end
end
