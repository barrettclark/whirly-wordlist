import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Focus the first empty input when the page loads
    const first = this.inputTargets.find(i => i.value === "")
    if (first) first.focus()
  }

  input(event) {
    const input = event.target
    // Enforce single letter and uppercase display
    input.value = input.value.replace(/[^a-zA-Z]/g, "").slice(-1).toUpperCase()

    if (input.value.length === 1) {
      const index = this.inputTargets.indexOf(input)
      if (index === this.inputTargets.length - 1) {
        // Last box filled — submit
        this.element.requestSubmit()
      } else {
        this.inputTargets[index + 1].focus()
      }
    }
  }

  keydown(event) {
    if (event.key === "Backspace" && event.target.value === "") {
      const index = this.inputTargets.indexOf(event.target)
      if (index > 0) {
        const prev = this.inputTargets[index - 1]
        prev.value = ""
        prev.focus()
      }
    }
  }

  paste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData)
      .getData("text")
      .replace(/[^a-zA-Z]/g, "")
      .toUpperCase()
      .slice(0, this.inputTargets.length)

    text.split("").forEach((letter, i) => {
      this.inputTargets[i].value = letter
    })

    if (text.length === this.inputTargets.length) {
      this.element.requestSubmit()
    } else {
      const next = this.inputTargets[text.length]
      if (next) next.focus()
    }
  }
}
