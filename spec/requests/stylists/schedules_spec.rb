# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Schedules' do
  describe 'GET /show' do
    it 'returns http success' do
      get '/stylists/schedules/show'
      expect(response).to have_http_status(:success)
    end
  end
end
