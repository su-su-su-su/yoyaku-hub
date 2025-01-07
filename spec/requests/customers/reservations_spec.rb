# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers::Reservations' do
  describe 'GET /show' do
    it 'returns http success' do
      get '/customers/reservations/show'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /create' do
    it 'returns http success' do
      get '/customers/reservations/create'
      expect(response).to have_http_status(:success)
    end
  end
end
