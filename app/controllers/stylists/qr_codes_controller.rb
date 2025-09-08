# frozen_string_literal: true

module Stylists
  class QrCodesController < Stylists::ApplicationController
    def show
      require 'rqrcode'

      url = params[:url]
      return render plain: 'URL is required', status: :bad_request if url.blank?

      qrcode = RQRCode::QRCode.new(url)

      svg = qrcode.as_svg(
        color: '000',
        shape_rendering: 'crispEdges',
        module_size: 6,
        standalone: true,
        use_path: true
      )

      render plain: svg, content_type: 'image/svg+xml'
    end
  end
end
