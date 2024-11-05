# frozen_string_literal: true

class StylistsController < ApplicationController
  before_action :authenticate_user!
end
