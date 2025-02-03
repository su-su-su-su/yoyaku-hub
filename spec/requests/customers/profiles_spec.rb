# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Customers::Profiles' do
  describe 'GET /edit' do
    it 'returns http success' do
      get '/customers/profiles/edit'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /update' do
    it 'returns http success' do
      get '/customers/profiles/update'
      expect(response).to have_http_status(:success)
    end
  end
end
