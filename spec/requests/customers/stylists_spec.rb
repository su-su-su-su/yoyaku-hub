# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers::Stylists' do
  describe 'GET /index' do
    it 'returns http success' do
      get '/customers/stylists/index'
      expect(response).to have_http_status(:success)
    end
  end
end
