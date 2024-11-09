# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist_role

  def show
  end

  private

  def ensure_stylist_role
    ensure_role('stylist')
  end
end
