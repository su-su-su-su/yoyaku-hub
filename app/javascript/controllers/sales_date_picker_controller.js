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

  navigate() {
    // 既にナビゲーション中の場合は何もしない
    if (this.navigating) {
      return
    }

    // 既存のタイムアウトをクリア
    if (this.navigationTimeout) {
      clearTimeout(this.navigationTimeout)
    }

    // デバウンス: 500ms待ってから実行（モバイルでの連続イベントを防ぐ）
    this.navigationTimeout = setTimeout(() => {
      this.performNavigation()
    }, 500)
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
        // フォームを作成して送信（より安定した方法）
        const form = document.createElement('form')
        form.method = 'GET'
        form.action = '/stylists/sales'
        form.style.display = 'none'

        const yearInput = document.createElement('input')
        yearInput.name = 'year'
        yearInput.value = year
        form.appendChild(yearInput)

        const monthInput = document.createElement('input')
        monthInput.name = 'month'
        monthInput.value = month
        form.appendChild(monthInput)

        document.body.appendChild(form)
        form.submit()
      }
    } catch (error) {
      console.error('Navigation error:', error)
      this.navigating = false
    }
  }
}