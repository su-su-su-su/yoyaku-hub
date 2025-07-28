# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Chartes' do
  let(:stylist) { create(:stylist) }
  let(:customer) { create(:customer) }
  let(:charte) { create(:charte, stylist: stylist, customer: customer) }

  before { sign_in stylist }

  describe 'GET /stylists/customers/:customer_id/chartes' do
    it 'returns http success' do
      charte # ensure charte exists first
      get stylists_customer_chartes_path(customer)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /stylists/customers/:customer_id/chartes/:id' do
    it 'returns http success' do
      get stylists_customer_charte_path(customer, charte)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /stylists/customers/:customer_id/chartes/:id/edit' do
    it 'returns http success' do
      get edit_stylists_customer_charte_path(customer, charte)
      expect(response).to have_http_status(:success)
    end
  end
end
