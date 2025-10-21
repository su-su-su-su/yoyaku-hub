# frozen_string_literal: true

StripeEvent.signing_secret = ENV.fetch('STRIPE_WEBHOOK_SECRET', nil)

StripeEvent.configure do |events|
  # Checkout Session完了
  events.subscribe 'checkout.session.completed' do |event|
    session = event.data.object
    Rails.logger.info "Checkout Session完了イベント受信: Customer: #{session['customer']}, Subscription: #{session['subscription']}"

    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_customer_id: session['customer'])

    if user.nil?
      Rails.logger.warn "ユーザーが見つかりません: Customer ID: #{session['customer']}"
      next
    end

    Rails.logger.info "ユーザー発見: User ##{user.id}, 現在のsubscription_id: #{user.stripe_subscription_id || 'nil'}"

    # サブスクリプションIDを保存
    if session['subscription'].present?
      begin
        Rails.logger.info "更新を実行: subscription_id=#{session['subscription']}, status=trialing"
        # Webhook処理ではバリデーションをスキップ（プロフィール未入力でも保存可能にする）
        user.update_columns(
          stripe_subscription_id: session['subscription'],
          subscription_status: 'trialing',
          updated_at: Time.current
        )
        user.reload  # データベースから再読み込み
        Rails.logger.info "Checkout完了・更新成功: User ##{user.id}, Subscription: #{user.stripe_subscription_id}, Status: #{user.subscription_status}"
      rescue => e
        Rails.logger.error "Checkout完了時のエラー: User ##{user.id}, エラー: #{e.class} - #{e.message}"
      end
    else
      Rails.logger.warn "サブスクリプションIDが空です: session['subscription'] = #{session['subscription'].inspect}"
    end
  end

  # サブスクリプション作成
  events.subscribe 'customer.subscription.created' do |event|
    subscription = event.data.object
    Rails.logger.info "サブスクリプション作成イベント受信: Customer: #{subscription['customer']}, ID: #{subscription['id']}, Status: #{subscription['status']}"

    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_customer_id: subscription['customer'])

    if user.nil?
      Rails.logger.warn "ユーザーが見つかりません: Customer ID: #{subscription['customer']}"
      next
    end

    Rails.logger.info "ユーザー発見: User ##{user.id}, 現在のsubscription_id: #{user.stripe_subscription_id || 'nil'}"

    begin
      Rails.logger.info "更新を実行: subscription_id=#{subscription['id']}, status=#{subscription['status']}"
      # Webhook処理ではバリデーションをスキップ（プロフィール未入力でも保存可能にする）
      user.update_columns(
        stripe_subscription_id: subscription['id'],
        subscription_status: subscription['status'],
        updated_at: Time.current
      )
      user.reload  # データベースから再読み込み
      Rails.logger.info "サブスクリプション作成・更新成功: User ##{user.id}, Subscription: #{user.stripe_subscription_id}, Status: #{user.subscription_status}"
    rescue => e
      Rails.logger.error "サブスクリプション作成時のエラー: User ##{user.id}, エラー: #{e.class} - #{e.message}"
    end
  end

  # サブスクリプション更新
  events.subscribe 'customer.subscription.updated' do |event|
    subscription = event.data.object
    # unscopedを使用: 無効化されたユーザーもWebhookで更新可能にする
    user = User.unscoped.find_by(stripe_subscription_id: subscription['id'])

    next unless user

    # サブスクリプションステータスのみを更新（ホワイトリスト方式）
    allowed_statuses = %w[incomplete incomplete_expired trialing active past_due canceled unpaid paused]
    if allowed_statuses.include?(subscription['status'])
      user.update(subscription_status: subscription['status'])
      Rails.logger.info "サブスクリプション更新: User ##{user.id}, Status: #{subscription['status']}"
    else
      Rails.logger.warn "不正なステータス: User ##{user.id}, Status: #{subscription['status']}"
    end
  end

  # サブスクリプション削除
  events.subscribe 'customer.subscription.deleted' do |event|
    subscription = event.data.object
    user = User.unscoped.find_by(stripe_subscription_id: subscription['id'])

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
    subscription_id = invoice['subscription']

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
    subscription_id = invoice['subscription']

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
