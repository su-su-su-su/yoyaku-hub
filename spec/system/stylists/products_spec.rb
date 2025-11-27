# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stylists::Products' do
  let(:stylist) { create(:user, role: :stylist) }

  before do
    sign_in stylist
  end

  describe '商品一覧画面' do
    context 'when no products exist' do
      before do
        visit stylists_products_path
      end

      it '商品が登録されていないメッセージが表示される' do
        expect(page).to have_content('商品が登録されていません')
      end

      it '新規商品登録リンクが表示される' do
        expect(page).to have_link('新規商品登録', href: new_stylists_product_path)
      end
    end

    context 'when products exist' do
      let!(:active_product) { create(:product, user: stylist, name: 'シャンプー', default_price: 3000, active: true) }
      let!(:inactive_product) { create(:product, user: stylist, name: 'トリートメント', default_price: 5000, active: false) }

      before do
        visit stylists_products_path
      end

      it '商品情報が表示される' do
        expect(page).to have_content('シャンプー')
        expect(page).to have_content('¥3,000')
        expect(page).to have_content('トリートメント')
        expect(page).to have_content('¥5,000')
      end

      it '掲載ステータスが正しく表示される' do
        within('tr', text: 'シャンプー') do
          expect(page).to have_content('掲載中')
        end
        within('tr', text: 'トリートメント') do
          expect(page).to have_content('非掲載')
        end
      end

      it '編集リンクが表示される' do
        expect(page).to have_link('編集', href: edit_stylists_product_path(active_product))
        expect(page).to have_link('編集', href: edit_stylists_product_path(inactive_product))
      end
    end
  end

  describe '新規商品登録' do
    before do
      visit new_stylists_product_path
    end

    it '必要な入力フィールドが表示される' do
      expect(page).to have_field('商品名')
      expect(page).to have_field('価格（税込）')
      expect(page).to have_css('.toggle.toggle-primary')
      expect(page).to have_content('商品一覧に掲載する')
    end

    context 'with valid information' do
      it '商品が登録される' do
        fill_in '商品名', with: 'ヘアオイル'
        fill_in '価格（税込）', with: '4500'

        click_on '登録する'

        expect(page).to have_current_path(stylists_products_path)
        expect(page).to have_css('#toast-container .toast-message', text: '商品を登録しました。')
        expect(page).to have_content('ヘアオイル')
        expect(page).to have_content('¥4,500')
        expect(page).to have_content('掲載中')
      end
    end

    context 'with invalid information' do
      it '必須フィールドにrequired属性がある' do
        visit new_stylists_product_path

        # HTML5のrequired属性を確認
        expect(page).to have_css('input[name="product[name]"][required]')
        expect(page).to have_css('input[name="product[default_price]"][required]')
      end
    end
  end

  describe '商品編集' do
    let!(:product) { create(:product, user: stylist, name: 'ワックス', default_price: 2000, active: true) }

    before do
      visit edit_stylists_product_path(product)
    end

    it '現在の情報が表示される' do
      expect(page).to have_field('商品名', with: 'ワックス')
      expect(page).to have_field('価格（税込）', with: '2000')
      expect(page).to have_css('.toggle.toggle-primary')
      expect(page).to have_content('商品一覧に掲載する')
    end

    context 'when updating information' do
      it '商品情報が更新される' do
        fill_in '商品名', with: 'ヘアワックス'
        fill_in '価格（税込）', with: '2500'
        # トグルをクリックして非掲載にする
        find('.toggle.toggle-primary').click

        click_on '更新する'

        expect(page).to have_current_path(stylists_products_path)
        expect(page).to have_css('#toast-container .toast-message', text: '商品を更新しました。')
        expect(page).to have_content('ヘアワックス')
        expect(page).to have_content('¥2,500')
        expect(page).to have_content('非掲載')
      end
    end
  end

  describe 'ダッシュボードからのアクセス' do
    before do
      visit stylists_dashboard_path
    end

    it '商品管理メニューが表示される' do
      expect(page).to have_link('商品管理', href: stylists_products_path)
    end

    it '商品管理画面に遷移できる' do
      click_on '商品管理'
      expect(page).to have_current_path(stylists_products_path)
      expect(page).to have_content('商品管理')
    end
  end
end
