# frozen_string_literal: true

module Stylists
  class ProductsController < Stylists::ApplicationController
    before_action :set_product, only: %i[edit update destroy]

    def index
      @products = current_user.products.order(active: :desc, created_at: :desc)
    end

    def new
      @product = current_user.products.build
    end

    def edit; end

    def create
      @product = current_user.products.build(product_params)

      if @product.save
        redirect_to stylists_products_path, notice: t('stylists.products.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @product.update(product_params)
        redirect_to stylists_products_path, notice: t('stylists.products.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product.update(active: false)
      redirect_to stylists_products_path, notice: t('stylists.products.hidden')
    end

    private

    def set_product
      @product = current_user.products.find(params[:id])
    end

    def product_params
      params.require(:product).permit(:name, :default_price, :active)
    end
  end
end
