# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stripe Webhooks' do
  let(:stylist) do
    create(:user, :stylist,
      stripe_customer_id: 'cus_test123',
      stripe_subscription_id: nil,
      subscription_status: nil)
  end

  # Stripe Eventを構築するヘルパーメソッド
  def build_stripe_event(type, data)
    # data.objectをStripe::StripeObjectとして構築
    stripe_object = case type
                    when 'checkout.session.completed'
                      Stripe::Checkout::Session.construct_from(data)
                    when 'customer.subscription.created',
                         'customer.subscription.updated',
                         'customer.subscription.deleted'
                      Stripe::Subscription.construct_from(data)
                    when 'invoice.payment_succeeded', 'invoice.payment_failed'
                      Stripe::Invoice.construct_from(data)
                    else
                      Stripe::StripeObject.construct_from(data)
                    end

    Stripe::Event.construct_from({
      id: "evt_#{SecureRandom.hex(12)}",
      object: 'event',
      type: type,
      data: {
        object: stripe_object
      }
    })
  end

  # rubocop:disable RSpec/NestedGroups
  describe 'Webhook event handlers' do
    context 'checkout.session.completed event' do
      let(:trial_end_time) { 1.month.from_now }
      let(:event) do
        build_stripe_event('checkout.session.completed', {
          customer: stylist.stripe_customer_id,
          subscription: 'sub_test123'
        })
      end

      before do
        # Stripe::Subscription.retrieveをモック
        subscription_mock = instance_double(Stripe::Subscription,
          trial_end: trial_end_time.to_i)
        allow(Stripe::Subscription).to receive(:retrieve).with('sub_test123').and_return(subscription_mock)
      end

      it 'updates user with subscription ID' do
        expect do
          StripeEvent.instrument(event)
        end.to change { stylist.reload.stripe_subscription_id }.from(nil).to('sub_test123')

        expect(stylist.subscription_status).to eq('trialing')
        expect(stylist.trial_ends_at).to be_within(1.second).of(trial_end_time)
      end
    end

    context 'customer.subscription.created event' do
      let(:trial_end_time) { 1.month.from_now }
      let(:event) do
        build_stripe_event('customer.subscription.created', {
          id: 'sub_test123',
          customer: stylist.stripe_customer_id,
          status: 'trialing',
          trial_end: trial_end_time.to_i
        })
      end

      it 'creates subscription for user' do
        expect do
          StripeEvent.instrument(event)
        end.to change { stylist.reload.stripe_subscription_id }.from(nil).to('sub_test123')

        expect(stylist.subscription_status).to eq('trialing')
        expect(stylist.trial_ends_at).to be_within(1.second).of(trial_end_time)
      end
    end

    context 'customer.subscription.updated event' do
      before do
        stylist.update(
          stripe_subscription_id: 'sub_test123',
          subscription_status: 'trialing'
        )
      end

      let(:event) do
        build_stripe_event('customer.subscription.updated', {
          id: 'sub_test123',
          customer: stylist.stripe_customer_id,
          status: 'active'
        })
      end

      it 'updates subscription status' do
        expect do
          StripeEvent.instrument(event)
        end.to change { stylist.reload.subscription_status }.from('trialing').to('active')
      end

      context 'when status is invalid' do
        let(:event) do
          build_stripe_event('customer.subscription.updated', {
            id: 'sub_test123',
            customer: stylist.stripe_customer_id,
            status: 'invalid_status'
          })
        end

        it 'does not update subscription status' do
          expect do
            StripeEvent.instrument(event)
          end.not_to(change { stylist.reload.subscription_status })
        end
      end
    end

    context 'customer.subscription.deleted event' do
      before do
        stylist.update(
          stripe_subscription_id: 'sub_test123',
          subscription_status: 'active',
          status: :active
        )
      end

      let(:event) do
        build_stripe_event('customer.subscription.deleted', {
          id: 'sub_test123',
          customer: stylist.stripe_customer_id
        })
      end

      it 'deactivates user and removes subscription' do
        StripeEvent.instrument(event)

        stylist.reload
        expect(stylist.stripe_subscription_id).to be_nil
        expect(stylist.subscription_status).to eq('canceled')
        expect(stylist.status).to eq('inactive')
      end
    end

    context 'invoice.payment_succeeded event' do
      before do
        stylist.update(
          stripe_subscription_id: 'sub_test123',
          subscription_status: 'active',
          status: :inactive
        )
      end

      let(:event) do
        build_stripe_event('invoice.payment_succeeded', {
          subscription: 'sub_test123',
          customer: stylist.stripe_customer_id,
          amount_paid: 3850
        })
      end

      it 'reactivates inactive user' do
        expect do
          StripeEvent.instrument(event)
        end.to change { stylist.reload.status }.from('inactive').to('active')
      end

      context 'when user is already active' do
        before do
          stylist.update(status: :active)
        end

        it 'does not change user status' do
          expect do
            StripeEvent.instrument(event)
          end.not_to(change { stylist.reload.status })
        end
      end
    end

    context 'invoice.payment_failed event' do
      before do
        stylist.update(
          stripe_subscription_id: 'sub_test123',
          subscription_status: 'active',
          status: :active
        )
      end

      let(:event) do
        build_stripe_event('invoice.payment_failed', {
          id: 'in_test123',
          subscription: 'sub_test123',
          customer: stylist.stripe_customer_id
        })
      end

      it 'deactivates user and updates status' do
        StripeEvent.instrument(event)

        stylist.reload
        expect(stylist.status).to eq('inactive')
        expect(stylist.subscription_status).to eq('past_due')
      end
    end

    context 'when user does not exist' do
      let(:event) do
        build_stripe_event('customer.subscription.created', {
          id: 'sub_test123',
          customer: 'cus_nonexistent',
          status: 'trialing'
        })
      end

      it 'handles gracefully without error' do
        expect do
          StripeEvent.instrument(event)
        end.not_to raise_error
      end
    end
  end
  # rubocop:enable RSpec/NestedGroups
end
