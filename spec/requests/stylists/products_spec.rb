# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Products' do
  let(:user) { create(:user, :stylist) }
  let(:product) { create(:product, user: user) }

  before do
    sign_in user
  end

  describe 'GET /stylists/products' do
    it 'returns http success' do
      get stylists_products_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /stylists/products/new' do
    it 'returns http success' do
      get new_stylists_product_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /stylists/products' do
    let(:valid_params) do
      { product: { name: 'テスト商品', default_price: 3000, active: true } }
    end

    it 'creates a new product' do
      expect do
        post stylists_products_path, params: valid_params
      end.to change(Product, :count).by(1)
    end

    it 'redirects to products index' do
      post stylists_products_path, params: valid_params
      expect(response).to redirect_to(stylists_products_path)
    end
  end

  describe 'GET /stylists/products/:id/edit' do
    it 'returns http success' do
      get edit_stylists_product_path(product)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH /stylists/products/:id' do
    let(:update_params) do
      { product: { name: '更新商品', default_price: 5000 } }
    end

    it 'updates the product' do
      patch stylists_product_path(product), params: update_params
      expect(product.reload.name).to eq('更新商品')
    end

    it 'redirects to products index' do
      patch stylists_product_path(product), params: update_params
      expect(response).to redirect_to(stylists_products_path)
    end
  end

  describe 'DELETE /stylists/products/:id' do
    it 'makes product inactive' do
      delete stylists_product_path(product)
      expect(product.reload.active).to be_falsey
    end

    it 'redirects to products index' do
      delete stylists_product_path(product)
      expect(response).to redirect_to(stylists_products_path)
    end
  end
end
