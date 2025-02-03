# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Profiles' do
  describe 'GET /edit' do
    it 'returns http success' do
      get '/stylists/profiles/edit'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /update' do
    it 'returns http success' do
      get '/stylists/profiles/update'
      expect(response).to have_http_status(:success)
    end
  end
end
