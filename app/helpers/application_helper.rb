# frozen_string_literal: true

module ApplicationHelper
  def render_navbar
    if user_signed_in?
      if current_user.stylist?
        render 'layouts/navbars/stylist_navbar'
      else
        render 'layouts/navbars/customer_navbar'
      end
    else
      render 'layouts/navbars/guest_navbar'
    end
  end
end
