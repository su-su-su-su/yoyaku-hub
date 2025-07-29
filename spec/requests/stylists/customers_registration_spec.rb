# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Stylists::Customers Registration and Update' do
  let(:stylist) { create(:user, :stylist) }
  let(:other_stylist) { create(:user, :stylist) }

  before do
    sign_in stylist
  end

  describe 'GET /stylists/customers/new' do
    it 'renders the customer registration form' do
      get new_stylists_customer_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('顧客登録')
    end
  end

  describe 'POST /stylists/customers' do
    let(:valid_params) do
      {
        user: {
          family_name: '田中',
          given_name: '太郎',
          family_name_kana: 'タナカ',
          given_name_kana: 'タロウ',
          gender: 'male',
          date_of_birth: '1990-01-01',
          email: 'tanaka@example.com'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new customer with created_by_stylist_id' do
        expect do
          post stylists_customers_path, params: valid_params
        end.to change(User, :count).by(1)

        customer = User.last
        expect(customer.role).to eq('customer')
        expect(customer.created_by_stylist_id).to eq(stylist.id)
        expect(customer.family_name).to eq('田中')
        expect(customer.given_name).to eq('太郎')
        expect(customer.email).to eq('tanaka@example.com')
      end

      it 'redirects to customers index with success message' do
        post stylists_customers_path, params: valid_params
        expect(response).to redirect_to(stylists_customers_path)
        follow_redirect!
        expect(response.body).to include('顧客を登録しました。')
      end
    end

    context 'when email is blank' do
      it 'generates a dummy email' do
        params_without_email = valid_params.dup
        params_without_email[:user][:email] = ''

        post stylists_customers_path, params: params_without_email

        customer = User.last
        expect(customer.email).to match(/dummy_\d{14}_[a-zA-Z0-9]{8}@no-email-dummy\.invalid/)
        expect(customer.dummy_email?).to be true
      end
    end

    context 'with invalid parameters (missing name)' do
      let(:invalid_params) do
        {
          user: {
            family_name: '',
            given_name: '',
            family_name_kana: 'タナカ',
            given_name_kana: 'タロウ',
            gender: 'male',
            date_of_birth: '1990-01-01'
          }
        }
      end

      it 'does not create a customer' do
        expect do
          post stylists_customers_path, params: invalid_params
        end.not_to change(User, :count)
      end

      it 'renders the new template with errors' do
        post stylists_customers_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('顧客登録')
      end
    end

    context 'with minimal required parameters' do
      let(:minimal_params) do
        {
          user: {
            family_name: '山田',
            given_name: '花子',
            family_name_kana: 'ヤマダ',
            given_name_kana: 'ハナコ',
            gender: 'female'
          }
        }
      end

      it 'creates customer without date_of_birth and email' do
        expect do
          post stylists_customers_path, params: minimal_params
        end.to change(User, :count).by(1)

        customer = User.last
        expect(customer.date_of_birth).to be_nil
        expect(customer.dummy_email?).to be true
      end
    end
  end

  describe 'GET /stylists/customers/:id/edit' do
    let(:manual_customer) { create(:user, :customer, created_by_stylist_id: stylist.id) }
    let(:other_manual_customer) { create(:user, :customer, created_by_stylist_id: other_stylist.id) }

    context 'when editing own registered customer' do
      it 'renders the edit form' do
        get edit_stylists_customer_path(manual_customer)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('顧客情報編集')
      end
    end

    context 'when trying to edit other stylist\'s customer' do
      it 'returns not found' do
        get edit_stylists_customer_path(other_manual_customer)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /stylists/customers/:id' do
    let(:manual_customer) { create(:user, :customer, created_by_stylist_id: stylist.id) }
    let(:other_manual_customer) { create(:user, :customer, created_by_stylist_id: other_stylist.id) }

    let(:update_params) do
      {
        user: {
          family_name: '更新',
          given_name: '太郎',
          family_name_kana: 'コウシン',
          given_name_kana: 'タロウ',
          gender: 'male',
          email: 'updated@example.com'
        }
      }
    end

    context 'when updating own registered customer' do
      it 'updates the customer successfully' do
        patch stylists_customer_path(manual_customer), params: update_params

        manual_customer.reload
        expect(manual_customer.family_name).to eq('更新')
        expect(manual_customer.email).to eq('updated@example.com')
        expect(response).to redirect_to(stylists_customer_path(manual_customer))
      end

      it 'generates dummy email when email is blank' do
        update_params[:user][:email] = ''
        patch stylists_customer_path(manual_customer), params: update_params

        manual_customer.reload
        expect(manual_customer.dummy_email?).to be true
      end
    end

    context 'when trying to update other stylist\'s customer' do
      it 'returns not found' do
        patch stylists_customer_path(other_manual_customer), params: update_params
        expect(response).to have_http_status(:not_found)
      end
    end

    # rubocop:disable RSpec/MultipleMemoizedHelpers
    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          user: {
            family_name: '',
            given_name: '',
            family_name_kana: 'タナカ',
            given_name_kana: 'タロウ'
          }
        }
      end

      it 'renders edit template with errors' do
        patch stylists_customer_path(manual_customer), params: invalid_update_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('顧客情報編集')
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
# rubocop:enable Metrics/BlockLength
