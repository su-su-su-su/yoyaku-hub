import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  update(event) {
    const selectedDate = event.target.value;
    const stylistIdElement = document.querySelector("#stylist_id");
    if (!stylistIdElement) {
      console.error("stylist_id の hidden field が見つかりません");
      return;
    }
    const stylistId = stylistIdElement.value;

    console.log("Selected Date:", selectedDate, "Stylist ID:", stylistId);

    const url = `/stylists/reservations/update_time_options?start_date_str=${selectedDate}&stylist_id=${stylistId}`;
    fetch(url, {
      headers: { Accept: "text/html" },
    })
      .then((response) => response.text())
      .then((html) => {
        console.log("取得したHTML:", html);
        const frame = document.getElementById("time_select_frame");
        if (frame) {
          frame.innerHTML = html;
        } else {
          console.error("time_select_frame が見つかりません");
        }
      })
      .catch((error) => console.error("Error updating time options:", error));
  }
}
