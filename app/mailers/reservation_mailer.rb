# frozen_string_literal: true

class ReservationMailer
  def initialize
    @service = SendgridService.new
  end

  # カスタマーが予約を登録した時の確認メール
  def reservation_confirmation(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    html_content = render_reservation_confirmation_html
    text_content = render_reservation_confirmation_text

    @service.send_email(
      to: @customer.email,
      subject: "【YOYAKU HUB】#{format_date(@reservation.start_at)}のご予約を承りました",
      html_content: html_content,
      text_content: text_content
    )
  end

  # カスタマーが予約をキャンセルした時の確認メール
  def cancellation_confirmation(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    html_content = render_cancellation_confirmation_html
    text_content = render_cancellation_confirmation_text

    @service.send_email(
      to: @customer.email,
      subject: '【YOYAKU HUB】ご予約をキャンセルしました',
      html_content: html_content,
      text_content: text_content
    )
  end

  # 美容師への新規予約通知
  def new_reservation_notification(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    html_content = render_new_reservation_notification_html
    text_content = render_new_reservation_notification_text

    @service.send_email(
      to: @stylist.email,
      subject: "【YOYAKU HUB】#{format_date(@reservation.start_at)}に新規予約が入りました",
      html_content: html_content,
      text_content: text_content
    )
  end

  # 美容師への予約キャンセル通知
  def cancellation_notification(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    html_content = render_cancellation_notification_html_for_stylist
    text_content = render_cancellation_notification_text_for_stylist

    @service.send_email(
      to: @stylist.email,
      subject: "【YOYAKU HUB】#{format_date(@reservation.start_at)}の予約がキャンセルされました",
      html_content: html_content,
      text_content: text_content
    )
  end

  # 美容師が予約を変更した時のカスタマーへの通知
  def reservation_updated_notification(reservation, changes = {})
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus
    @changes = changes

    html_content = render_reservation_updated_html
    text_content = render_reservation_updated_text

    @service.send_email(
      to: @customer.email,
      subject: '【YOYAKU HUB】ご予約内容が変更されました',
      html_content: html_content,
      text_content: text_content
    )
  end

  # 美容師が予約をキャンセルした時のカスタマーへの通知
  def reservation_canceled_by_stylist(reservation)
    @reservation = reservation
    @customer = reservation.customer
    @stylist = reservation.stylist
    @menus = reservation.menus

    html_content = render_reservation_canceled_by_stylist_html
    text_content = render_reservation_canceled_by_stylist_text

    @service.send_email(
      to: @customer.email,
      subject: '【YOYAKU HUB】重要：ご予約がキャンセルされました',
      html_content: html_content,
      text_content: text_content
    )
  end

  private

  def format_date(datetime)
    wday = %w[日 月 火 水 木 金 土][datetime.wday]
    datetime.strftime("%m月%d日(#{wday}) %H:%M")
  end

  def format_full_datetime(datetime)
    wday = %w[日 月 火 水 木 金 土][datetime.wday]
    datetime.strftime("%Y年%m月%d日(#{wday}) %H:%M")
  end

  def render_reservation_confirmation_html
    reservation_url = "#{Rails.application.config.base_url}/customers/reservations/#{@reservation.id}"

    content = <<~CONTENT
      <p>#{@customer.family_name} #{@customer.given_name}様</p>
      <p>この度はYOYAKU HUBをご利用いただき、ありがとうございます。<br>
      以下の内容でご予約を承りました。</p>

      #{reservation_details_section}

      <p style="text-align: center;">
        <a href="#{reservation_url}" class="button">予約の詳細を確認</a>
      </p>

      <p>ご予約の変更・キャンセルは、マイページから行えます。</p>
      <p>当日はお気をつけてお越しください。</p>
    CONTENT

    email_layout(content)
  end

  def render_reservation_confirmation_text
    reservation_url = "#{Rails.application.config.base_url}/customers/reservations/#{@reservation.id}"

    <<~TEXT
      #{@customer.family_name} #{@customer.given_name}様

      この度はYOYAKU HUBをご利用いただき、ありがとうございます。
      以下の内容でご予約を承りました。

      【予約内容】
      日時: #{format_full_datetime(@reservation.start_at)}
      スタイリスト: #{@stylist.family_name} #{@stylist.given_name}

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      合計時間: #{@menus.sum(&:duration)}分
      合計金額: #{number_to_currency(@menus.sum(&:price))}

      予約の詳細はこちら:
      #{reservation_url}

      ご予約の変更・キャンセルは、マイページから行えます。
      当日はお気をつけてお越しください。

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def render_cancellation_confirmation_html
    stylist_url = "#{Rails.application.config.base_url}/customers/stylists/#{@stylist.id}/menus"

    content = <<~CONTENT
      <p>#{@customer.family_name} #{@customer.given_name}様</p>
      <p>以下のご予約をキャンセルいたしました。</p>

      #{cancellation_details_section}

      <p style="text-align: center;">
        <a href="#{stylist_url}" class="button">別の日時で予約する</a>
      </p>

      <p>またのご利用をお待ちしております。</p>
    CONTENT

    email_layout(content)
  end

  def render_cancellation_confirmation_text
    stylist_url = "#{Rails.application.config.base_url}/customers/stylists/#{@stylist.id}/menus"

    <<~TEXT
      #{@customer.family_name} #{@customer.given_name}様

      以下のご予約をキャンセルいたしました。

      【キャンセルした予約内容】
      日時: #{format_full_datetime(@reservation.start_at)}
      スタイリスト: #{@stylist.family_name} #{@stylist.given_name}

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      別の日時で予約する:
      #{stylist_url}

      またのご利用をお待ちしております。

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def render_new_reservation_notification_html
    reservation_url = "#{Rails.application.config.base_url}/stylists/reservations/#{@reservation.id}"

    content = <<~CONTENT
      <p>#{@stylist.family_name} #{@stylist.given_name}様</p>
      <p>YOYAKU HUBから予約が入りました。</p>

      #{stylist_reservation_details_section}

      <p style="text-align: center;">
        <a href="#{reservation_url}" class="button">予約の詳細を確認</a>
      </p>
    CONTENT

    email_layout(content)
  end

  def render_new_reservation_notification_text
    reservation_url = "#{Rails.application.config.base_url}/stylists/reservations/#{@reservation.id}"

    <<~TEXT
      #{@stylist.family_name} #{@stylist.given_name}様

      YOYAKU HUBから予約が入りました。

      【予約内容】
      日時: #{format_full_datetime(@reservation.start_at)}
      お客様: #{@customer.family_name} #{@customer.given_name}様

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      合計時間: #{@menus.sum(&:duration)}分
      合計金額: #{number_to_currency(@menus.sum(&:price))}

      予約の詳細はこちら:
      #{reservation_url}

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def render_cancellation_notification_html_for_stylist
    content = <<~CONTENT
      <p>#{@stylist.family_name} #{@stylist.given_name}様</p>
      <p>以下の予約がキャンセルされました。</p>

      #{stylist_cancellation_details_section}
    CONTENT

    email_layout(content, additional_styles: '.reservation-details { border: 2px solid #FF9800; }')
  end

  def render_cancellation_notification_text_for_stylist
    <<~TEXT
      #{@stylist.family_name} #{@stylist.given_name}様

      以下の予約がキャンセルされました。

      【キャンセルされた予約】
      日時: #{format_full_datetime(@reservation.start_at)}
      お客様: #{@customer.family_name} #{@customer.given_name}様

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def render_reservation_updated_html
    reservation_url = "#{Rails.application.config.base_url}/customers/reservations/#{@reservation.id}"

    content = <<~CONTENT
      <p>#{@customer.family_name} #{@customer.given_name}様</p>
      <p>ご予約内容が以下のように変更されました。</p>

      #{updated_reservation_details_section}

      <p style="text-align: center;">
        <a href="#{reservation_url}" class="button">予約の詳細を確認</a>
      </p>

      <p>当日はお気をつけてお越しください。</p>
    CONTENT

    email_layout(content)
  end

  def render_reservation_updated_text
    reservation_url = "#{Rails.application.config.base_url}/customers/reservations/#{@reservation.id}"

    <<~TEXT
      #{@customer.family_name} #{@customer.given_name}様

      ご予約内容が以下のように変更されました。

      【変更後の予約内容】
      日時: #{format_full_datetime(@reservation.start_at)}
      スタイリスト: #{@stylist.family_name} #{@stylist.given_name}

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      合計時間: #{@menus.sum(&:duration)}分
      合計金額: #{number_to_currency(@menus.sum(&:price))}

      予約の詳細はこちら:
      #{reservation_url}

      当日はお気をつけてお越しください。

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def render_reservation_canceled_by_stylist_html
    stylist_url = "#{Rails.application.config.base_url}/customers/stylists/#{@stylist.id}/menus"

    content = <<~CONTENT
      <p>#{@customer.family_name} #{@customer.given_name}様</p>
      <p>スタイリストにより、以下のご予約をキャンセルさせていただきました。</p>

      #{stylist_canceled_reservation_details_section}

      <p>別の日時でのご予約をご検討いただければ幸いです。</p>

      <p style="text-align: center;">
        <a href="#{stylist_url}" class="button">別の日時で予約する</a>
      </p>
    CONTENT

    email_layout(content)
  end

  def render_reservation_canceled_by_stylist_text
    stylist_url = "#{Rails.application.config.base_url}/customers/stylists/#{@stylist.id}/menus"

    <<~TEXT
      #{@customer.family_name} #{@customer.given_name}様

      スタイリストにより、以下のご予約をキャンセルさせていただきました。

      【キャンセルになった予約】
      日時: #{format_full_datetime(@reservation.start_at)}
      スタイリスト: #{@stylist.family_name} #{@stylist.given_name}

      メニュー:
      #{@menus.map { |m| "・#{m.name}" }.join("\n")}

      別の日時でのご予約をご検討いただければ幸いです。

      別の日時で予約する:
      #{stylist_url}

      --
      このメールは自動送信されています。
      返信はできませんのでご了承ください。

      YOYAKU HUB
    TEXT
  end

  def number_to_currency(amount)
    "¥#{amount.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')}"
  end

  def common_styles
    <<~CSS
      body { font-family: 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; }
      .container { max-width: 600px; margin: 0 auto; padding: 20px; }
      .content { padding: 20px; background-color: #f9f9f9; }
      .reservation-details { background-color: white; padding: 20px; margin: 20px 0; border-radius: 5px; }
      .detail-row { display: flex; padding: 10px 0; border-bottom: 1px solid #eee; }
      .detail-label { font-weight: bold; width: 120px; color: #666; }
      .detail-value { flex: 1; }
      .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
      .button { display: inline-block; padding: 12px 30px; background-color: #2196F3; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    CSS
  end

  def email_layout(content, additional_styles: '')
    <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <style>
            #{common_styles}
            #{additional_styles}
          </style>
        </head>
        <body>
          <div class="container">
            <div class="content">
              #{content}
            </div>
            <div class="footer">
              <p>このメールは自動送信されています。<br>
              返信はできませんのでご了承ください。</p>
              <p>&copy; YOYAKU HUB</p>
            </div>
          </div>
        </body>
      </html>
    HTML
  end

  def reservation_details_section(include_price: true)
    <<~HTML
      <div class="reservation-details">
        <h3>予約内容</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">スタイリスト</div>
          <div class="detail-value">#{@stylist.family_name} #{@stylist.given_name}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
        #{price_and_duration_rows if include_price}
      </div>
    HTML
  end

  def price_and_duration_rows
    <<~HTML
      <div class="detail-row">
        <div class="detail-label">合計時間</div>
        <div class="detail-value">#{@menus.sum(&:duration)}分</div>
      </div>
      <div class="detail-row">
        <div class="detail-label">合計金額</div>
        <div class="detail-value">#{number_to_currency(@menus.sum(&:price))}</div>
      </div>
    HTML
  end

  def cancellation_details_section
    <<~HTML
      <div class="reservation-details">
        <h3>キャンセルした予約内容</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">スタイリスト</div>
          <div class="detail-value">#{@stylist.family_name} #{@stylist.given_name}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
      </div>
    HTML
  end

  def stylist_reservation_details_section
    <<~HTML
      <div class="reservation-details">
        <h3>予約内容</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">お客様</div>
          <div class="detail-value">#{@customer.family_name} #{@customer.given_name}様</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
        #{price_and_duration_rows}
      </div>
    HTML
  end

  def stylist_cancellation_details_section
    <<~HTML
      <div class="reservation-details">
        <h3>キャンセルされた予約</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">お客様</div>
          <div class="detail-value">#{@customer.family_name} #{@customer.given_name}様</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
      </div>
    HTML
  end

  def updated_reservation_details_section
    <<~HTML
      <div class="reservation-details">
        <h3>変更後の予約内容</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">スタイリスト</div>
          <div class="detail-value">#{@stylist.family_name} #{@stylist.given_name}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
        #{price_and_duration_rows}
      </div>
    HTML
  end

  def stylist_canceled_reservation_details_section
    <<~HTML
      <div class="reservation-details">
        <h3>キャンセルになった予約</h3>
        <div class="detail-row">
          <div class="detail-label">日時</div>
          <div class="detail-value">#{format_full_datetime(@reservation.start_at)}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">スタイリスト</div>
          <div class="detail-value">#{@stylist.family_name} #{@stylist.given_name}</div>
        </div>
        <div class="detail-row">
          <div class="detail-label">メニュー</div>
          <div class="detail-value">
            #{@menus.map(&:name).join('<br>')}
          </div>
        </div>
      </div>
    HTML
  end
end
