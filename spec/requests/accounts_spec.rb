# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accounts' do
  let(:stylist) do
    create(:user, :stylist,
      stripe_customer_id: 'cus_test123',
      stripe_subscription_id: 'sub_test123',
      subscription_status: 'active')
  end
  let(:customer) { create(:user, :customer) }

  before do
    # Stripe APIキーをモック設定
    allow(Rails.configuration.stripe).to receive(:[]).with(:secret_key).and_return('sk_test_123')
  end

  describe 'GET /account/deactivate' do
    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        get deactivate_account_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is customer' do
      before { sign_in customer }

      it 'redirects to root path with alert' do
        get deactivate_account_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('このページにアクセスする権限がありません。')
      end
    end

    context 'when user is stylist' do
      before { sign_in stylist }

      it 'shows account deactivation page' do
        get deactivate_account_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE /account/deactivate' do
    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        delete deactivate_account_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when stylist deactivates account successfully' do
      before do
        sign_in stylist
        # Stripe API呼び出しをモック
        allow(Stripe::Subscription).to receive(:cancel).and_return(true)
      end

      it 'deactivates user and redirects to root' do
        delete deactivate_account_path

        expect(stylist.reload.status).to eq('inactive')
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('退会処理が完了しました。ご利用ありがとうございました。')
      end
    end

    context 'when stylist has no active subscription' do
      let(:stylist_without_subscription) do
        create(:user, :stylist,
          stripe_customer_id: 'cus_test123',
          stripe_subscription_id: nil,
          subscription_status: nil,
          trial_ends_at: 1.day.from_now) # トライアル中なのでアクセス可能
      end

      before do
        sign_in stylist_without_subscription
      end

      it 'deactivates user without canceling subscription' do
        allow(Stripe::Subscription).to receive(:cancel)

        delete deactivate_account_path

        expect(Stripe::Subscription).not_to have_received(:cancel)
        expect(stylist_without_subscription.reload.status).to eq('inactive')
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('退会処理が完了しました。ご利用ありがとうございました。')
      end
    end

    context 'when Stripe subscription cancelation fails' do
      before do
        sign_in stylist
        # Stripeのエラーを発生させる
        allow(stylist).to receive(:deactivate_account!).and_raise(
          Stripe::InvalidRequestError.new('Subscription not found', 'subscription')
        )
        allow(User).to receive(:find).and_return(stylist)
      end

      it 'shows error and redirects back' do
        delete deactivate_account_path

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('サブスクリプションの解約に失敗しました。サポートにお問い合わせください。')
      end
    end

    context 'when user deactivation fails' do
      before do
        sign_in stylist
        allow(stylist).to receive(:deactivate_account!).and_raise(
          ActiveRecord::RecordInvalid.new(stylist)
        )
        allow(User).to receive(:find).and_return(stylist)
      end

      it 'shows error message and redirects back' do
        delete deactivate_account_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('退会処理に失敗しました。サポートにお問い合わせください。')
      end
    end
  end
end
