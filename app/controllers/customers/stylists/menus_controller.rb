# frozen_string_literal: true

module Customers
  module Stylists
    class MenusController < Customers::ApplicationController
      before_action :set_stylist
      before_action :authorize_menu_access

      def index
        @menus = @stylist.menus.where(is_active: true).order(:sort_order)
      end

      def select_menus
        if params[:menu_ids].blank?
          return redirect_with_toast customers_stylist_menus_path(@stylist),
            t('flash.menu_not_selected'), type: :error
        end

        redirect_to weekly_customers_stylist_menus_path(@stylist, menu_ids: params[:menu_ids])
      end

      private

      def set_stylist
        @stylist = User.find_by(id: params[:stylist_id])

        return if @stylist&.stylist?

        return if valid_stylist_target?(@stylist)

        flash_message = determine_set_stylist_error_flash_message
        redirect_path = determine_set_stylist_error_redirect_path
        redirect_with_toast redirect_path, flash_message, type: :error and return
      end

      def valid_stylist_target?(stylist_candidate)
        stylist_candidate&.stylist?
      end

      def determine_set_stylist_error_flash_message
        if current_user&.customer?
          t('flash.customers.stylists.stylist_not_found')
        else
          t('flash.customers.stylists.invalid_access')
        end
      end

      def determine_set_stylist_error_redirect_path
        if current_user&.customer?
          customers_dashboard_path
        elsif current_user&.stylist?
          stylists_dashboard_path
        else
          root_path
        end
      end

      def authorize_menu_access
        return unless @stylist

        if current_user.customer?

          true
        elsif current_user.stylist?
          unless current_user.id == @stylist.id
            redirect_with_toast stylists_dashboard_path,
              t('flash.customers.stylists.cannot_view_other_stylist_menus'), type: :error and return
          end

          true
        else
          redirect_with_toast root_path, t('flash.customers.stylists.access_denied'), type: :error and return
        end
      end
    end
  end
end
