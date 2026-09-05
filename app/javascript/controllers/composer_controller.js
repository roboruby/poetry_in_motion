import { Controller } from "@hotwired/stimulus"

// The chat composer: Enter sends, Shift+Enter breaks a line, suggestion
// chips fill and send, and the field clears once the turn is accepted.
export default class extends Controller {
  static targets = ["form", "input"]

  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.submit()
    }
  }

  suggest(event) {
    const prompt = event.params.prompt
    if (!prompt) return
    this.inputTarget.value = prompt
    this.submit()
  }

  submit() {
    if (this.inputTarget.value.trim() === "") return
    this.formTarget.requestSubmit()
  }

  reset(event) {
    if (event?.detail?.success === false) return
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }
}
