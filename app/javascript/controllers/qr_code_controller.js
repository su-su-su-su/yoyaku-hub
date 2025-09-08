import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "modal", "container"]

  async show() {
    if (!this.hasUrlTarget) {
      return
    }
    
    const url = this.urlTarget.value
    
    try {
      const response = await fetch(`/stylists/qr_code?url=${encodeURIComponent(url)}`, {
        headers: {
          'Accept': 'image/svg+xml',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const svgText = await response.text()
        this.containerTarget.innerHTML = svgText
        this.modalTarget.classList.add("modal-open")
      }
    } catch (error) {
      console.error("Error generating QR code:", error)
    }
  }

  hide() {
    this.modalTarget.classList.remove("modal-open")
  }
}