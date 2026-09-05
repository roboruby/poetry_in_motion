import { Controller } from "@hotwired/stimulus"

// The workspace's shape: the chat sits center stage while the canvas is
// empty ("hero"), docks to the bottom-right once the first surface lands
// ("docked"), and collapses to a pill on request ("minimized").
export default class extends Controller {
  static targets = ["surfaces", "unread"]
  static values = { state: { type: String, default: "hero" } }

  connect() {
    this.unread = 0
    this.surfaceObserver = new MutationObserver(() => this.surfacesChanged())
    this.surfaceObserver.observe(this.surfacesTarget, { childList: true })
    const messages = this.element.querySelector("#chat-messages")
    if (messages) {
      this.messageObserver = new MutationObserver((mutations) => this.messagesChanged(mutations))
      this.messageObserver.observe(messages, { childList: true })
    }
    this.apply()
  }

  disconnect() {
    this.surfaceObserver?.disconnect()
    this.messageObserver?.disconnect()
  }

  stateValueChanged() {
    this.apply()
  }

  minimize() {
    this.stateValue = "minimized"
  }

  expand() {
    this.stateValue = this.hasSurfaces ? "docked" : "hero"
  }

  toggle() {
    this.stateValue === "minimized" ? this.expand() : this.minimize()
  }

  get hasSurfaces() {
    return this.surfacesTarget.children.length > 0
  }

  surfacesChanged() {
    if (this.hasSurfaces && this.stateValue === "hero") this.stateValue = "docked"
    if (!this.hasSurfaces && this.stateValue === "docked") this.stateValue = "hero"
  }

  messagesChanged(mutations) {
    if (this.stateValue !== "minimized") return
    if (mutations.some((mutation) => mutation.addedNodes.length > 0)) {
      this.unread += 1
      this.renderUnread()
    }
  }

  apply() {
    this.element.dataset.state = this.stateValue
    if (this.stateValue !== "minimized") {
      this.unread = 0
      this.renderUnread()
    }
  }

  renderUnread() {
    if (!this.hasUnreadTarget) return
    this.unreadTarget.hidden = this.unread === 0
    this.unreadTarget.textContent = String(this.unread)
  }
}
