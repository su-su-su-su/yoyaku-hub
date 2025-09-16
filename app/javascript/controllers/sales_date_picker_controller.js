import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["year", "month"]

  connect() {
    this.navigating = false
    this.navigationTimeout = null
  }

  disconnect() {
    if (this.navigationTimeout) {
      clearTimeout(this.navigationTimeout)
    }
  }

  navigate(event) {
    // モバイルChromeの検出
    const isMobileChrome = /Android.*Chrome|CriOS/i.test(navigator.userAgent)

    if (isMobileChrome) {
      // モバイルChromeの場合、blurイベントを待つ
      if (event && event.type === 'change') {
        // changeイベントの場合、選択が確定するまで待機
        event.target.addEventListener('blur', () => {
          this.scheduleNavigation()
        }, { once: true })
        return
      }
    }

    this.scheduleNavigation()
  }

  scheduleNavigation() {
    // 既にナビゲーション中の場合は何もしない
    if (this.navigating) {
      return
    }

    // 既存のタイムアウトをクリア
    if (this.navigationTimeout) {
      clearTimeout(this.navigationTimeout)
    }

    // デバウンス: 1000ms待ってから実行（モバイルでより長い待機）
    this.navigationTimeout = setTimeout(() => {
      this.performNavigation()
    }, 1000)
  }

  performNavigation() {
    // 二重実行を防ぐ
    if (this.navigating) {
      return
    }

    try {
      this.navigating = true

      const year = this.yearTarget.value
      const month = this.monthTarget.value

      if (year && month) {
        // URLパラメータを構築
        const params = new URLSearchParams({ year, month })
        const url = `/stylists/sales?${params.toString()}`

        // location.hrefを使用（form.submit()よりも安定）
        window.location.href = url
      } else {
        // 値が不正な場合はナビゲーションをリセット
        this.navigating = false
      }
    } catch (error) {
      console.error('Navigation error:', error)
      this.navigating = false
    }
  }
}