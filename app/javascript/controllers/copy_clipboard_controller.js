import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["source", "button"];
  static values = {
    successText: { type: String, default: "コピー完了!" },
    originalButtonHtml: String,
  };

  connect() {
    if (this.hasButtonTarget && !this.originalButtonHtmlValue) {
      this.originalButtonHtmlValue = this.buttonTarget.innerHTML;
    }
  }

  _updateButtonFeedback(isSuccess) {
    if (!this.hasButtonTarget) return;

    const button = this.buttonTarget;
    const originalHTML = this.originalButtonHtmlValue || "コピー";

    if (isSuccess) {
      const successIconHTML = `<svg class="w-4 h-4 mr-1" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg>`;
      button.innerHTML = `${successIconHTML}${this.successTextValue}`;
    } else {
    }

    setTimeout(() => {
      button.innerHTML = originalHTML;
    }, 2000);
  }

  copy() {
    if (!this.hasSourceTarget) {
      console.error("Copy source target is not defined.");
      return;
    }
    const textToCopy = this.sourceTarget.value;

    if (this.hasButtonTarget) {
      this.originalButtonHtmlValue = this.buttonTarget.innerHTML;
    }

    if (!navigator.clipboard) {
      try {
        this.sourceTarget.select();
        document.execCommand("copy");
        this._updateButtonFeedback(true);
      } catch (err) {
        console.error("フォールバックコピーに失敗しました: ", err);
        this._updateButtonFeedback(false);
        alert("URLのコピーに失敗しました。手動でコピーしてください。");
      }
      return;
    }

    navigator.clipboard
      .writeText(textToCopy)
      .then(() => {
        this._updateButtonFeedback(true);
      })
      .catch((err) => {
        console.error("URLのコピーに失敗しました: ", err);
        this._updateButtonFeedback(false);
        alert(
          "URLのコピーに失敗しました。お手数ですが、手動でコピーしてください。"
        );
      });
  }
}
