import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "selected", "selectedName"];

  connect() {
    this.debounceTimeout = null;
  }

  debounceSearch(event) {
    clearTimeout(this.debounceTimeout);

    this.debounceTimeout = setTimeout(() => {
      const form = event.target.closest("form");
      if (form) {
        form.requestSubmit();
      }
    }, 300);
  }

  selectCustomer(event) {
    const customerId = event.currentTarget.dataset.customerId;
    const customerName = event.currentTarget.dataset.customerName;

    document.getElementById("selected_customer_id").value = customerId;

    this.selectedNameTarget.textContent = customerName;

    const searchFormContainer = this.element.querySelector(".mb-4");
    if (searchFormContainer) {
      searchFormContainer.style.display = "none";
    }
    this.selectedTarget.classList.remove("hidden");
  }

  clearSelection() {
    document.getElementById("selected_customer_id").value = "";

    this.selectedTarget.classList.add("hidden");

    const searchFormContainer = this.element.querySelector(".mb-4");
    if (searchFormContainer) {
      searchFormContainer.style.display = "block";
    }

    const searchField = this.element.querySelector(
      'input[name="customer_search"]'
    );
    if (searchField) {
      searchField.value = "";
      const form = searchField.closest("form");
      if (form) {
        form.requestSubmit();
      }
    }
  }
}
