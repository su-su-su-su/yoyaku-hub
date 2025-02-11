# frozen_string_literal: true

module Customers
  module Stylists
    class MenusController < ApplicationController
      def index
        @stylist = User.find(params[:stylist_id])
        @menus = @stylist.menus.where(is_active: true)
      end

      def select_menus
        @stylist = User.find(params[:stylist_id])

        if params[:menu_ids].blank?
          flash[:alert] = I18n.t('flash.menu_not_selected')
          redirect_to customers_stylist_menus_path(@stylist)
          return
        end

        redirect_to weekly_customers_stylist_menus_path(@stylist, menu_ids: params[:menu_ids])
      end
    end
  end
end
