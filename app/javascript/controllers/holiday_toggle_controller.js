import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "startTime", "endTime", "maxReservations"];

  connect() {
    this.originalStartTime = this.startTimeTarget.value;
    this.originalEndTime = this.endTimeTarget.value;
    this.originalMaxReservations = this.maxReservationsTarget.value;

    this.toggle();
  }

  toggle() {
    const isHoliday = this.checkboxTarget.checked;

    if (isHoliday) {
      this.startTimeTarget.value = "00:00";
      this.endTimeTarget.value = "00:00";
      this.maxReservationsTarget.value = "0";

      this.startTimeTarget.disabled = true;
      this.endTimeTarget.disabled = true;
      this.maxReservationsTarget.disabled = true;
    } else {
      this.startTimeTarget.value = this.originalStartTime;
      this.endTimeTarget.value = this.originalEndTime;
      this.maxReservationsTarget.value = this.originalMaxReservations;

      this.startTimeTarget.disabled = false;
      this.endTimeTarget.disabled = false;
      this.maxReservationsTarget.disabled = false;
    }
  }
}
