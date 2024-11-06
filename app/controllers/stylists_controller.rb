# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_stylist_role

  private

  def ensure_stylist_role
    ensure_role('stylist')
  end
end
