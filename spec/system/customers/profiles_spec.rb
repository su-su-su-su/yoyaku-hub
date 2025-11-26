# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Customers::Profiles' do
  let(:customer) { create(:customer) }
  let(:valid_attributes) do
    {
      family_name: '予約',
      given_name: '太郎',
      family_name_kana: 'ヨヤク',
      given_name_kana: 'タロウ',
      gender: 'male',
      date_of_birth: Date.new(1990, 1, 1)
    }
  end

  # JavaScriptドライバーを使用（トースト通知のため）

  describe 'Profile editing' do
    context 'when logged in as a customer' do
      before do
        sign_in customer
        visit edit_customers_profile_path
      end

      it 'displays the profile edit page' do
        expect(page).to have_content('カスタマー情報')
        expect(page).to have_field('姓')
        expect(page).to have_field('名')
        expect(page).to have_field('セイ (カタカナ)')
        expect(page).to have_field('メイ (カタカナ)')
        expect(page).to have_field('user[gender]', type: 'radio', count: 3)
        expect(page).to have_select('user_date_of_birth_1i')
      end

      it 'when entering valid information, updates profile and redirects to dashboard' do
        fill_in_profile_form(valid_attributes)
        click_on '登録情報を更新する'

        expect(page).to have_current_path(customers_dashboard_path)
        expect(page).to have_css('#toast-container .toast-message', text: I18n.t('customers.profiles.updated'))

        customer.reload
        expect_user_attributes_match(customer, valid_attributes)
      end

      it 'when required fields are empty, displays errors' do
        fill_in '姓', with: ''
        fill_in '名', with: ''
        click_on '登録情報を更新する'

        expect(page).to have_content('を入力してください')
        # バリデーションエラー時はeditページが再表示される
        expect(page).to have_css('form[action="/customers/profile"]')
      end

      it 'when entering invalid values for katakana fields, displays errors' do
        # HTML5バリデーションを無効化するために、JavaScriptでpattern属性を削除
        page.execute_script("document.getElementById('user_family_name_kana').removeAttribute('pattern')")
        page.execute_script("document.getElementById('user_given_name_kana').removeAttribute('pattern')")

        fill_in 'セイ (カタカナ)', with: 'よやく'
        fill_in 'メイ (カタカナ)', with: 'たろう'
        click_on '登録情報を更新する'

        expect(page).to have_content('全角カタカナのみ入力できます')
        # バリデーションエラー時はeditページが再表示される
        expect(page).to have_css('form[action="/customers/profile"]')
      end

      it 'when selecting "no answer" for gender, saves that value' do
        fill_in_profile_form(valid_attributes.merge(gender: 'no_answer'))
        click_on '登録情報を更新する'

        expect(page).to have_current_path(customers_dashboard_path)
        customer.reload
        expect(customer.gender).to eq('no_answer')
      end
    end

    context 'when not logged in' do
      it 'redirects to the login page' do
        visit edit_customers_profile_path
        expect(page).to have_current_path(new_user_session_path)
      end
    end

    context 'when logged in with a different role (stylist)' do
      let(:stylist) { create(:stylist) }

      it 'redirects to the root path' do
        sign_in stylist
        visit edit_customers_profile_path
        expect(page).to have_current_path(root_path)
      end
    end

    context 'when accessing via stylist QR code/URL' do
      let(:stylist) { create(:user, :stylist) }
      let!(:menu) { create(:menu, stylist: stylist, name: 'カット', price: 6600, duration: 60, is_active: true) } # rubocop:disable RSpec/LetSetup

      it 'redirects to the stylist menu page after login' do
        # 未ログインでスタイリストメニューページにアクセス（stored_locationを保存）
        visit customers_stylist_menus_path(stylist)

        # ログインページにリダイレクト
        expect(page).to have_current_path(new_user_session_path)

        # カスタマーでログイン
        fill_in 'user_email', with: customer.email
        fill_in 'user_password', with: 'testtest'
        click_on 'ログイン'

        # stored_locationにより、元のスタイリストメニューページにリダイレクトされることを確認
        expect(page).to have_current_path(customers_stylist_menus_path(stylist), ignore_query: true)
        expect(page).to have_text("担当: #{stylist.family_name} #{stylist.given_name}")
        expect(page).to have_content('カット')
      end
    end

    context 'when registering directly (not via stylist URL)' do
      let(:direct_customer) do
        # プロフィール未完了の新規カスタマーを作成
        create(:user, :customer,
          family_name: nil,
          given_name: nil,
          family_name_kana: nil,
          given_name_kana: nil,
          gender: nil,
          date_of_birth: nil)
      end

      it 'redirects to customer dashboard after profile registration' do
        # プロフィール未完了のカスタマーでログイン
        sign_in direct_customer

        # プロフィール編集ページにアクセス
        visit edit_customers_profile_path

        # プロフィール情報を入力
        fill_in_profile_form(valid_attributes)
        click_on '登録情報を更新する'

        # 従来通りダッシュボードにリダイレクト（stored_locationがないため）
        expect(page).to have_current_path(customers_dashboard_path)
        expect(page).to have_css('#toast-container .toast-message', text: I18n.t('customers.profiles.updated'))
      end
    end
  end

  private

  def fill_in_profile_form(attributes)
    fill_in '姓', with: attributes[:family_name]
    fill_in '名', with: attributes[:given_name]
    fill_in 'セイ (カタカナ)', with: attributes[:family_name_kana]
    fill_in 'メイ (カタカナ)', with: attributes[:given_name_kana]

    select_gender(attributes[:gender])
    select_birth_date(attributes[:date_of_birth])
  end

  def select_gender(gender)
    case gender
    when 'male'
      choose '男性'
    when 'female'
      choose '女性'
    when 'no_answer'
      choose '答えない'
    end
  end

  def select_birth_date(date)
    select date.year.to_s, from: 'user_date_of_birth_1i'
    select date.month.to_s, from: 'user_date_of_birth_2i'
    select date.day.to_s, from: 'user_date_of_birth_3i'
  end

  def expect_user_attributes_match(user, attributes)
    aggregate_failures 'user attributes should match' do
      expect_name_attributes_match(user, attributes)
      expect_kana_attributes_match(user, attributes)
      expect_other_attributes_match(user, attributes)
    end
  end

  def expect_name_attributes_match(user, attributes)
    expect(user.family_name).to eq(attributes[:family_name])
    expect(user.given_name).to eq(attributes[:given_name])
  end

  def expect_kana_attributes_match(user, attributes)
    expect(user.family_name_kana).to eq(attributes[:family_name_kana])
    expect(user.given_name_kana).to eq(attributes[:given_name_kana])
  end

  def expect_other_attributes_match(user, attributes)
    expect(user.gender).to eq(attributes[:gender])
    expect(user.date_of_birth).to eq(attributes[:date_of_birth])
  end
end
# rubocop:enable Metrics/BlockLength
