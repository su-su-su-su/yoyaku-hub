# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:set_role]

  def set_role
    role = params[:role]
    if %w[stylist customer].include?(role)
      session[:role] = role
      redirect_to user_google_oauth2_omniauth_authorize_path
    else
      redirect_to new_user_session_path
    end
  end
end