# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist_role

  def show
    @stylist = current_user
    @today = Time.zone.today
  end
end
