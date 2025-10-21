# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin::Users' do
  let(:admin) { create(:user, role: :admin) }
  let(:stylist_with_subscription) do
    create(:user, :stylist,
      stripe_customer_id: 'cus_test123',
      stripe_subscription_id: 'sub_test123',
      subscription_status: 'active')
  end

  before do
    sign_in admin
    # Stripe APIキーをモック設定
    allow(Rails.configuration.stripe).to receive(:[]).with(:secret_key).and_return('sk_test_123')
  end

  describe 'DELETE /admin/users/:id (destroy)' do
    context 'when deactivating a stylist with active subscription' do
      before do
        # Stripe APIモック
        allow(Stripe::Subscription).to receive(:cancel).and_return(true)
      end

      it 'deactivates user and cancels Stripe subscription' do
        delete admin_user_path(stylist_with_subscription)

        expect(Stripe::Subscription).to have_received(:cancel).with('sub_test123')
        expect(stylist_with_subscription.reload.status).to eq('inactive')
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.deactivated'))
      end
    end

    context 'when Stripe subscription cancelation fails' do
      before do
        allow(Stripe::Subscription).to receive(:cancel).and_raise(
          Stripe::InvalidRequestError.new('Subscription not found', 'subscription')
        )
      end

      it 'shows error and does not deactivate user' do
        delete admin_user_path(stylist_with_subscription)

        expect(stylist_with_subscription.reload.status).to eq('active')
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:alert]).to eq(I18n.t('flash.admin.users.stripe_cancel_failed'))
      end
    end

    context 'when deactivating a stylist without subscription' do
      let(:stylist_without_subscription) do
        create(:user, :stylist,
          stripe_customer_id: 'cus_test123',
          stripe_subscription_id: nil,
          subscription_status: nil)
      end

      it 'deactivates user without calling Stripe API' do
        allow(Stripe::Subscription).to receive(:cancel)

        delete admin_user_path(stylist_without_subscription)

        expect(Stripe::Subscription).not_to have_received(:cancel)
        expect(stylist_without_subscription.reload.status).to eq('inactive')
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.deactivated'))
      end
    end

    context 'when admin tries to deactivate themselves' do
      it 'shows error and does not deactivate' do
        delete admin_user_path(admin)

        expect(admin.reload.status).to eq('active')
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:alert]).to eq(I18n.t('flash.admin.users.cannot_deactivate_self'))
      end
    end

    context 'when trying to deactivate the last admin' do
      let(:another_admin) { create(:user, role: :admin) }

      before do
        # 2人の管理者が存在する状態にする
        another_admin
      end

      it 'allows deactivation when not the last admin' do
        delete admin_user_path(another_admin)

        expect(another_admin.reload.status).to eq('inactive')
        expect(response).to redirect_to(admin_users_path)
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.deactivated'))
      end
    end
  end

  describe 'PATCH /admin/users/:id (update)' do
    context 'when changing stylist status to inactive' do
      before do
        # Stripe APIモック
        allow(Stripe::Subscription).to receive(:cancel).and_return(true)
      end

      it 'deactivates user and cancels Stripe subscription' do
        patch admin_user_path(stylist_with_subscription), params: {
          user: {
            status: 'inactive'
          }
        }

        expect(Stripe::Subscription).to have_received(:cancel).with('sub_test123')
        expect(stylist_with_subscription.reload.status).to eq('inactive')
        expect(stylist_with_subscription.stripe_subscription_id).to be_nil
        expect(response).to redirect_to(admin_user_path(stylist_with_subscription))
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.deactivated'))
      end
    end

    context 'when updating other attributes' do
      it 'updates user without affecting Stripe subscription' do
        allow(Stripe::Subscription).to receive(:cancel)

        patch admin_user_path(stylist_with_subscription), params: {
          user: {
            family_name: '新しい名前'
          }
        }

        expect(Stripe::Subscription).not_to have_received(:cancel)
        expect(stylist_with_subscription.reload.family_name).to eq('新しい名前')
        expect(stylist_with_subscription.status).to eq('active')
        expect(response).to redirect_to(admin_user_path(stylist_with_subscription))
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.updated'))
      end
    end

    context 'when changing customer status to inactive' do
      let(:customer) { create(:user, :customer) }

      it 'deactivates user without calling Stripe API' do
        allow(Stripe::Subscription).to receive(:cancel)

        patch admin_user_path(customer), params: {
          user: {
            status: 'inactive'
          }
        }

        expect(Stripe::Subscription).not_to have_received(:cancel)
        expect(customer.reload.status).to eq('inactive')
        expect(response).to redirect_to(admin_user_path(customer))
        expect(flash[:notice]).to eq(I18n.t('flash.admin.users.updated'))
      end
    end

    context 'when Stripe subscription cancelation fails' do
      before do
        allow(Stripe::Subscription).to receive(:cancel).and_raise(
          Stripe::InvalidRequestError.new('Subscription not found', 'subscription')
        )
      end

      it 'shows error and does not deactivate user' do
        patch admin_user_path(stylist_with_subscription), params: {
          user: {
            status: 'inactive'
          }
        }

        expect(stylist_with_subscription.reload.status).to eq('active')
        expect(response).to redirect_to(admin_user_path(stylist_with_subscription))
        expect(flash[:alert]).to eq(I18n.t('flash.admin.users.stripe_cancel_failed'))
      end
    end
  end
end
