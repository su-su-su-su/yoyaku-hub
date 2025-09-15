import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    const yearSelect = document.getElementById('year-select')
    const monthSelect = document.getElementById('month-select')

    const year = yearSelect.value
    const month = monthSelect.value

    const url = `/stylists/sales?year=${year}&month=${month}`
    window.location.href = url
  }
}