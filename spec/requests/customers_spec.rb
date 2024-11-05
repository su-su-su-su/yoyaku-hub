# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers' do
  describe 'GET /dashboard' do
    it 'returns http success' do
      get '/customers/dashboard'
      expect(response).to have_http_status(:success)
    end
  end
end
