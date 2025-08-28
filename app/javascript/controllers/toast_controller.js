import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    message: String,
    type: { type: String, default: "info" },
    duration: { type: Number, default: 3000 }
  }

  connect() {
    this.show()
    this.autoHide()
  }

  show() {
    requestAnimationFrame(() => {
      // フェードイン＋スケールアニメーション
      this.element.classList.remove("opacity-0", "scale-95")
      this.element.classList.add("opacity-100", "scale-100")
    })
  }

  hide() {
    // フェードアウト＋スケールアニメーション
    this.element.classList.remove("opacity-100", "scale-100")
    this.element.classList.add("opacity-0", "scale-95")
    
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }

  autoHide() {
    if (this.durationValue > 0) {
      setTimeout(() => {
        this.hide()
      }, this.durationValue)
    }
  }

  close() {
    this.hide()
  }
}