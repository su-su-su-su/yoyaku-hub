import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // ページ読み込み時にdata-toast属性があるか確認
    const toastData = this.element.dataset.toast
    if (toastData && toastData !== '') {
      try {
        const { message, type } = JSON.parse(toastData)
        window.showToast(message, type)
        // 表示後は属性を削除
        delete this.element.dataset.toast
      } catch (e) {
        console.error("Failed to parse toast data:", e)
      }
    }

    // Turboのキャッシュ前にtoast属性をクリア
    document.addEventListener('turbo:before-cache', this.clearToast.bind(this))
  }

  disconnect() {
    document.removeEventListener('turbo:before-cache', this.clearToast.bind(this))
  }

  clearToast() {
    // キャッシュされる前にtoast属性とコンテナをクリア
    delete this.element.dataset.toast
    this.element.innerHTML = ''
  }
}

// トーストを生成する共通関数
function createToastHtml(message, type) {
  const alertClasses = {
    success: "alert-info",
    error: "alert-error", 
    alert: "alert-error",
    warning: "alert-warning",
    info: "alert-info"
  }
  
  const alertClass = alertClasses[type] || "alert-info"
  const id = `toast-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`
  const customStyle = (type === 'success' || type === 'info') ? 
    'style="background-color: #7eaaef; color: white;"' : ''
  const buttonStyle = (type === 'success' || type === 'info') ? 'text-white hover:text-gray-200' : ''

  return `
    <div id="${id}" class="alert ${alertClass} toast-message transform scale-95 opacity-0 transition-all duration-500 ease-in-out shadow-lg min-w-[300px] max-w-md flex items-center justify-between"
         ${customStyle}
         data-controller="toast"
         data-toast-message-value="${message}"
         data-toast-type-value="${type}"
         data-toast-duration-value="3000">
      <span class="flex-1">${message}</span>
      <button class="btn btn-ghost btn-xs ${buttonStyle}" data-action="click->toast#close" type="button">
        <svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </button>
    </div>
  `
}

// グローバル関数として公開
window.showToast = function(message, type = "info") {
  const container = document.getElementById("toast-container")
  if (!container) return
  
  container.insertAdjacentHTML("beforeend", createToastHtml(message, type))
}