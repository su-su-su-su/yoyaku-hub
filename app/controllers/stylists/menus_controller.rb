# frozen_string_literal: true

module Stylists
  class MenusController < ApplicationController
    before_action :authenticate_user!
    before_action -> { ensure_role(:stylist) }
    before_action :set_menu, only: %i[edit update]
    before_action :load_menus, only: %i[index create update]

    def index; end

    def new
      @menu = Menu.new
      respond_to do |format|
        format.html
        format.turbo_stream { render partial: 'form', locals: { menu: @menu } }
      end
    end

    def edit; end

    def create
      @menu = current_user.menus.new(menu_params)
      if @menu.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to menus_settings_path, notice: t('stylists.menus.created') }
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @menu.update(menu_params)
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to menus_settings_path, notice: t('stylists.menus.updated') }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_menu
      @menu = current_user.menus.find(params[:id])
    end

    def load_menus
      @menus = current_user.menus.order(:sort_order)
    end

    def menu_params
      params.require(:menu).permit(:sort_order, :name, :price, :duration, :description, :is_active, category: [])
    end
  end
end
