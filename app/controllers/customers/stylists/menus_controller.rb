# frozen_string_literal: true

module Customers
  module Stylists
    class MenusController < ApplicationController
      before_action :authenticate_user!
      before_action -> { ensure_role(:customer) }
      before_action :ensure_stylist_resource

      def index
        @stylist = User.find(params[:stylist_id])
        @menus = @stylist.menus.where(is_active: true).order(:sort_order)
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

      private

      def ensure_stylist_resource
        @stylist = User.find(params[:stylist_id])
        return if @stylist.stylist?

        redirect_to customers_dashboard_path
      end
    end
  end
end
