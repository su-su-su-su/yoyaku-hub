import { Controller } from "stimulus";

export default class extends Controller {
  connect() {
    setTimeout(() => {
      this.element.style.transition = "opacity 1s ease-out";
      this.element.style.opacity = 0;
    }, 2000);
  }
}
