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
        expect(page).to have_field('性')
        expect(page).to have_field('名')
        expect(page).to have_field('セイ')
        expect(page).to have_field('メイ')
        expect(page).to have_field('user[gender]', type: 'radio', count: 3)
        expect(page).to have_select('user_date_of_birth_1i')
      end

      it 'when entering valid information, updates profile and redirects to dashboard' do
        fill_in_profile_form(valid_attributes)
        click_on '登録'

        expect(page).to have_current_path(customers_dashboard_path)
        expect(page).to have_css('#toast-container .toast-message', text: I18n.t('customers.profiles.updated'))

        customer.reload
        expect_user_attributes_match(customer, valid_attributes)
      end

      it 'when required fields are empty, displays errors' do
        fill_in '性', with: ''
        fill_in '名', with: ''
        click_on '登録'

        expect(page).to have_content('を入力してください')
        # バリデーションエラー時はeditページが再表示される
        expect(page).to have_css('form[action="/customers/profile"]')
      end

      it 'when entering invalid values for katakana fields, displays errors' do
        # HTML5バリデーションを無効化するために、JavaScriptでpattern属性を削除
        page.execute_script("document.getElementById('user_family_name_kana').removeAttribute('pattern')")
        page.execute_script("document.getElementById('user_given_name_kana').removeAttribute('pattern')")
        
        fill_in 'セイ', with: 'よやく'
        fill_in 'メイ', with: 'たろう'
        click_on '登録'

        expect(page).to have_content('全角カタカナのみ入力できます')
        # バリデーションエラー時はeditページが再表示される
        expect(page).to have_css('form[action="/customers/profile"]')
      end

      it 'when selecting "no answer" for gender, saves that value' do
        fill_in_profile_form(valid_attributes.merge(gender: 'no_answer'))
        click_on '登録'

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
  end

  private

  def fill_in_profile_form(attributes)
    fill_in '性', with: attributes[:family_name]
    fill_in '名', with: attributes[:given_name]
    fill_in 'セイ', with: attributes[:family_name_kana]
    fill_in 'メイ', with: attributes[:given_name_kana]

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
