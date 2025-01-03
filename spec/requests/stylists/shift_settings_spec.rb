# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::ShiftSettings' do
  describe 'GET /show' do
    it 'returns http success' do
      get '/stylists/shift_settings/show'
      expect(response).to have_http_status(:success)
    end
  end
end
