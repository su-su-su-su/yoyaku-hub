# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Subscriptions' do
  let(:stylist) do
    create(:user, :stylist,
      stripe_customer_id: nil,
      stripe_subscription_id: nil,
      trial_ends_at: nil,
      subscription_exempt: false)
  end
  let(:customer) { create(:user, :customer) }
  let(:admin) { create(:user, role: :admin) }

  before do
    # Stripe APIキーをモック設定
    allow(Rails.configuration.stripe).to receive(:[]).with(:secret_key).and_return('sk_test_123')
    allow(Rails.configuration.stripe).to receive(:[]).with(:price_id).and_return('price_123')
  end

  describe 'GET /subscription/new' do
    context 'when user is not signed in' do
      it 'redirects to sign in page' do
        get new_subscription_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is customer' do
      before { sign_in customer }

      it 'redirects to root path with alert' do
        get new_subscription_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('このページにアクセスする権限がありません。')
      end
    end

    context 'when user is stylist without subscription' do
      before do
        sign_in stylist
        # Stripe Customer作成をスタブ
        customer_stub = instance_double(Stripe::Customer, id: 'cus_test123')
        allow(Stripe::Customer).to receive(:create).and_return(customer_stub)
      end

      it 'creates Stripe Customer and shows subscription page' do
        get new_subscription_path
        expect(response).to have_http_status(:success)
        expect(stylist.reload.stripe_customer_id).to eq('cus_test123')
        expect(stylist.trial_ends_at).to be_present
      end
    end

    context 'when stylist already has active subscription' do
      before do
        stylist.update(
          stripe_subscription_id: 'sub_test123',
          subscription_status: 'active'
        )
        sign_in stylist
      end

      it 'redirects to dashboard with notice' do
        get new_subscription_path
        expect(response).to redirect_to(stylists_dashboard_path)
        expect(flash[:notice]).to eq('すでに有効なサブスクリプションが存在します。')
      end
    end

    context 'when Stripe Customer creation fails' do
      before do
        sign_in stylist
        allow(Stripe::Customer).to receive(:create).and_raise(
          Stripe::InvalidRequestError.new('Invalid email', 'email')
        )
      end

      it 'shows error message' do
        get new_subscription_path
        expect(response).to have_http_status(:success)
        expect(flash[:alert]).to eq('登録エラー: メールアドレスが無効です。正しいメールアドレスで再登録してください。')
      end
    end
  end

  describe 'POST /subscription' do
    let(:checkout_session) do
      instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.com/test')
    end

    before do
      stylist.update(
        stripe_customer_id: 'cus_test123',
        trial_ends_at: 6.months.from_now
      )
      sign_in stylist
    end

    context 'when Stripe Checkout Session is created successfully' do
      before do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)
      end

      it 'redirects to Stripe Checkout' do
        post subscription_path
        expect(response).to redirect_to('https://checkout.stripe.com/test')
        expect(response).to have_http_status(:see_other)
      end

      it 'creates session with correct parameters' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)

        post subscription_path

        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(
            customer: 'cus_test123',
            mode: 'subscription',
            line_items: [{ price: 'price_123', quantity: 1 }]
          )
        )
      end
    end

    context 'when Stripe Checkout Session creation fails' do
      before do
        allow(Stripe::Checkout::Session).to receive(:create).and_raise(
          Stripe::InvalidRequestError.new('Invalid customer', 'customer')
        )
      end

      it 'redirects back with alert' do
        post subscription_path
        expect(response).to redirect_to(new_subscription_path)
        expect(flash[:alert]).to eq('決済ページの作成に失敗しました。')
      end
    end

    context 'when user is not signed in' do
      before { sign_out stylist }

      it 'redirects to sign in page' do
        post subscription_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is customer' do
      before do
        sign_out stylist
        sign_in customer
      end

      it 'redirects to root path with alert' do
        post subscription_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('このページにアクセスする権限がありません。')
      end
    end
  end

  describe 'GET /subscription/success' do
    before do
      stylist.update(
        stripe_customer_id: 'cus_test123',
        stripe_subscription_id: 'sub_test123',
        subscription_status: 'trialing',
        trial_ends_at: 6.months.from_now
      )
      sign_in stylist
    end

    context 'when profile is incomplete' do
      before do
        allow(stylist).to receive(:profile_complete?).and_return(false)
      end

      it 'redirects to profile edit page' do
        get success_subscription_path
        expect(response).to redirect_to(edit_stylists_profile_path)
        expect(flash[:notice]).to eq('サブスクリプションの登録が完了しました。')
      end
    end

    context 'when profile is complete' do
      before do
        stylist.update(
          family_name: '山田',
          given_name: '太郎',
          family_name_kana: 'ヤマダ',
          given_name_kana: 'タロウ'
        )
      end

      it 'redirects to dashboard' do
        get success_subscription_path
        expect(response).to redirect_to(stylists_dashboard_path)
        expect(flash[:notice]).to eq('サブスクリプションの登録が完了しました。')
      end
    end

    context 'when user is not signed in' do
      before { sign_out stylist }

      it 'redirects to sign in page' do
        get success_subscription_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /subscription/cancel' do
    before { sign_in stylist }

    it 'redirects to new subscription page with alert' do
      get cancel_subscription_path
      expect(response).to redirect_to(new_subscription_path)
      expect(flash[:alert]).to eq('サブスクリプションの登録をキャンセルしました。')
    end

    context 'when user is not signed in' do
      before { sign_out stylist }

      it 'redirects to sign in page' do
        get cancel_subscription_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
