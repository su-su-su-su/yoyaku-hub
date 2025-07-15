import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    const selectedDate = event.target.value
    if (selectedDate) {
      window.location.href = `/stylists/schedules/${selectedDate}`
    }
  }
}