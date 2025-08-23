import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["paymentMethods", "totalAmount", "productItems"]
  static values = { 
    paymentIndex: Number,
    productIndex: Number,
    menuTotal: Number
  }

  connect() {
    this.paymentIndexValue = this.paymentMethodsTarget.children.length
    this.productIndexValue = this.hasProductItemsTarget ? this.productItemsTarget.children.length : 0
    this.menuTotalValue = parseInt(this.data.get('menuTotalValue')) || 0
    // 編集画面の場合は初回の計算をスキップ
    if (!this.data.get('skipInitialCalculation')) {
      this.updateTotalAmount()
    }
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

  addProduct() {
    const newProduct = this.createProductHtml(this.productIndexValue)
    this.productItemsTarget.insertAdjacentHTML('beforeend', newProduct)
    this.productIndexValue++
  }

  removeProduct(event) {
    const productItem = event.target.closest('.product-item')
    if (productItem) {
      // 既存の商品の場合は、_destroyフラグを立てて非表示にする
      const idField = productItem.querySelector('input[name*="[id]"]')
      if (idField && idField.value) {
        // 既存レコードの場合
        productItem.style.display = 'none'
        const destroyInput = document.createElement('input')
        destroyInput.type = 'hidden'
        destroyInput.name = idField.name.replace('[id]', '[_destroy]')
        destroyInput.value = '1'
        productItem.appendChild(destroyInput)
      } else {
        // 新規追加した商品の場合は完全に削除
        productItem.remove()
      }
      this.updateTotalAmount()
    }
  }

  updateProductPrice(event) {
    const select = event.target
    const productItem = select.closest('.product-item')
    const priceInput = productItem.querySelector('.product-price-input')
    const selectedOption = select.options[select.selectedIndex]
    
    if (selectedOption.value) {
      const defaultPrice = selectedOption.dataset.price
      priceInput.value = defaultPrice
    } else {
      priceInput.value = 0
    }
    this.updateTotalAmount()
  }

  updateProductQuantity(event) {
    this.updateTotalAmount()
  }

  updateProductActualPrice(event) {
    this.updateTotalAmount()
  }

  updateTotalAmount() {
    let productTotal = 0
    
    // 商品の合計を計算（表示されているものだけ）
    if (this.hasProductItemsTarget) {
      const productItems = this.productItemsTarget.querySelectorAll('.product-item')
      productItems.forEach(item => {
        // 非表示の要素（削除された商品）はスキップ
        if (item.style.display === 'none') return
        
        const priceInput = item.querySelector('.product-price-input')
        const quantityInput = item.querySelector('[name*="[quantity]"]')
        const price = parseInt(priceInput?.value) || 0
        const quantity = parseInt(quantityInput?.value) || 1
        productTotal += price * quantity
      })
    }
    
    // 合計金額を更新（メニュー料金 + 商品料金）
    const newTotal = this.menuTotalValue + productTotal
    this.totalAmountTarget.value = newTotal
    
    // 支払金額も更新（最初の支払方法のみ）
    const firstPaymentAmount = this.paymentMethodsTarget.querySelector('[name*="[amount]"]')
    if (firstPaymentAmount) {
      firstPaymentAmount.value = newTotal
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

  createProductHtml(index) {
    const products = JSON.parse(this.data.get('products') || '[]')
    const optionsHtml = products.map(p => 
      `<option value="${p.id}" data-price="${p.default_price}">${p.name}</option>`
    ).join('')

    return `
      <div class="product-item p-3 border border-gray-200 rounded-lg" data-product-index="${index}">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="form-group">
            <label class="block text-sm font-medium text-gray-700 mb-1">商品</label>
            <select name="accounting[accounting_products_attributes][${index}][product_id]" 
                    class="border border-gray-300 rounded px-3 py-2 w-full min-h-[44px]"
                    data-action="change->accounting#updateProductPrice">
              <option value="">商品を選択</option>
              ${optionsHtml}
            </select>
          </div>
          <div class="form-group">
            <label class="block text-sm font-medium text-gray-700 mb-1">数量</label>
            <input type="number" name="accounting[accounting_products_attributes][${index}][quantity]" 
                   class="border border-gray-300 rounded px-3 py-2 w-full min-h-[44px]" 
                   min="1" step="1" value="1"
                   data-action="input->accounting#updateProductQuantity">
          </div>
          <div class="form-group">
            <label class="block text-sm font-medium text-gray-700 mb-1">販売価格</label>
            <div class="relative">
              <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500">¥</span>
              <input type="number" name="accounting[accounting_products_attributes][${index}][actual_price]" 
                     class="product-price-input border border-gray-300 rounded px-3 py-2 pl-8 w-full min-h-[44px]" 
                     min="0" step="1" value="0"
                     data-action="input->accounting#updateProductActualPrice">
            </div>
          </div>
        </div>
        <div class="text-right mt-2">
          <button type="button" class="text-red-600 text-sm hover:text-red-800" data-action="click->accounting#removeProduct">この商品を削除</button>
        </div>
      </div>
    `
  }
}