# frozen_string_literal: true

StripeEvent.signing_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)

StripeEvent.configure do |events|
  # Checkout Session完了
  events.subscribe 'checkout.session.completed' do |event|
    session = event.data.object
    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_customer_id: session.customer)

    next unless user

    # サブスクリプションIDを保存
    if session.subscription.present?
      user.update(
        stripe_subscription_id: session.subscription,
        subscription_status: 'trialing'
      )
      Rails.logger.info "Checkout完了: User ##{user.id}, Subscription: #{session.subscription}"
    end
  end

  # サブスクリプション作成
  events.subscribe 'customer.subscription.created' do |event|
    subscription = event.data.object
    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_customer_id: subscription.customer)

    next unless user

    user.update(
      stripe_subscription_id: subscription.id,
      subscription_status: subscription.status
    )
    Rails.logger.info "サブスクリプション作成: User ##{user.id}, Status: #{subscription.status}"
  end

  # サブスクリプション更新
  events.subscribe 'customer.subscription.updated' do |event|
    subscription = event.data.object
    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_subscription_id: subscription.id)

    next unless user

    # サブスクリプションステータスのみを更新（ホワイトリスト方式）
    allowed_statuses = %w[incomplete incomplete_expired trialing active past_due canceled unpaid paused]
    if allowed_statuses.include?(subscription.status)
      user.update(subscription_status: subscription.status)
      Rails.logger.info "サブスクリプション更新: User ##{user.id}, Status: #{subscription.status}"
    else
      Rails.logger.warn "不正なステータス: User ##{user.id}, Status: #{subscription.status}"
    end
  end

  # サブスクリプション削除
  events.subscribe 'customer.subscription.deleted' do |event|
    subscription = event.data.object
    user = User.unscoped.find_by(stripe_subscription_id: subscription.id)

    next unless user

    # サブスクリプション削除時にユーザーを無効化
    user.update(
      subscription_status: 'canceled',
      stripe_subscription_id: nil,
      status: :inactive
    )
    Rails.logger.info "サブスクリプション削除・ユーザー無効化: User ##{user.id}"
  end

  # 支払い成功
  events.subscribe 'invoice.payment_succeeded' do |event|
    invoice = event.data.object
    subscription_id = invoice.subscription

    next unless subscription_id

    user = User.unscoped.find_by(stripe_subscription_id: subscription_id)

    next unless user

    # 支払い成功時にユーザーを有効化（無効化されていた場合）
    if user.inactive?
      user.update(status: :active)
      Rails.logger.info "支払い成功・ユーザー有効化: User ##{user.id}, Amount: #{invoice.amount_paid}"
    else
      Rails.logger.info "支払い成功: User ##{user.id}, Amount: #{invoice.amount_paid}"
    end
  end

  # 支払い失敗
  events.subscribe 'invoice.payment_failed' do |event|
    invoice = event.data.object
    subscription_id = invoice.subscription

    next unless subscription_id

    user = User.unscoped.find_by(stripe_subscription_id: subscription_id)

    next unless user

    # 支払い失敗時にユーザーを無効化し、サブスクリプションステータスを更新
    user.update(
      subscription_status: 'past_due',
      status: :inactive
    )
    Rails.logger.error "支払い失敗・ユーザー無効化: User ##{user.id}, Invoice: #{invoice.id}"

    # ここで管理者への通知やユーザーへのメール送信を実装可能
  end
end
