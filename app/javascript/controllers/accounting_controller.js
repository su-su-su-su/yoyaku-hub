import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["paymentMethods", "totalAmount"]
  static values = { paymentIndex: Number }

  connect() {
    this.paymentIndexValue = this.paymentMethodsTarget.children.length
  }

  addPaymentMethod() {
    const newPaymentMethod = this.createPaymentMethodHtml(this.paymentIndexValue)
    this.paymentMethodsTarget.insertAdjacentHTML('beforeend', newPaymentMethod)
    this.paymentIndexValue++
  }

  removePaymentMethod(event) {
    const paymentMethod = event.target.closest('.payment-method')
    if (paymentMethod) {
      paymentMethod.remove()
    }
  }

  createPaymentMethodHtml(index) {
    return `
      <div class="payment-method p-3 border border-gray-200 rounded-lg" data-payment-index="${index}">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div class="form-group">
            <label class="block text-sm font-medium text-gray-700 mb-1">支払方法</label>
            <select name="accounting[accounting_payments_attributes][${index}][payment_method]" class="border border-gray-300 rounded px-3 py-2 w-full min-h-[44px]" required title="お客様の支払方法を選択してください">
              <option value="">支払方法を選択</option>
              <option value="cash">現金</option>
              <option value="credit_card">クレジットカード</option>
              <option value="digital_pay">QR決済</option>
              <option value="other">その他</option>
            </select>
          </div>
          <div class="form-group">
            <label class="block text-sm font-medium text-gray-700 mb-1">支払金額</label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500">¥</span>
              <input type="number" name="accounting[accounting_payments_attributes][${index}][amount]" class="border border-gray-300 rounded px-3 py-2 pl-8 w-full min-h-[44px]" min="0" step="1" value="0" title="この支払方法での支払金額を入力してください" required>
            </div>
          </div>
        </div>
        <div class="text-right mt-2">
          <button type="button" class="text-red-600 text-sm hover:text-red-800" data-action="click->accounting#removePaymentMethod">この支払方法を削除</button>
        </div>
      </div>
    `
  }
}