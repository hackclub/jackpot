import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "message", "submitButton"]

  /**
   * Opens the RSVP modal overlay.
   */
  open() {
    this.modalTarget.classList.add("rsvp-modal--visible")
    document.body.style.overflow = "hidden"
  }

  /**
   * Closes the RSVP modal overlay and resets the form.
   */
  close() {
    this.modalTarget.classList.remove("rsvp-modal--visible")
    document.body.style.overflow = ""
  }

  /**
   * Closes modal only when clicking the backdrop (not the card content).
   * @param {Event} event - The click event on the overlay
   */
  closeBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  /**
   * Submits the RSVP form via fetch, sending emails, ref, and metadata.
   * @param {Event} event - The form submit event
   */
  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const emails = formData.getAll("emails[]").filter(e => e.trim() !== "")

    if (emails.length === 0) {
      this.showMessage("Please enter at least one email.", true)
      return
    }

    const urlParams = new URLSearchParams(window.location.search)
    const ref = urlParams.get("ref") || ""

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Submitting..."

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch("/rsvps", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ emails, ref })
      })

      const data = await response.json()

      if (response.ok) {
        this.showMessage("RSVP submitted! See you in Vegas 🎰", false)
        this.formTarget.reset()
        setTimeout(() => this.close(), 2000)
      } else {
        const errorMsg = data.error || data.errors?.map(e => e.errors.join(", ")).join("; ") || "Something went wrong."
        this.showMessage(errorMsg, true)
      }
    } catch (err) {
      this.showMessage("Network error. Please try again.", true)
    } finally {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Submit"
    }
  }

  /**
   * Displays a status message in the modal.
   * @param {string} text - The message to display
   * @param {boolean} isError - Whether this is an error message
   */
  showMessage(text, isError) {
    this.messageTarget.textContent = text
    this.messageTarget.className = isError ? "rsvp-message rsvp-message--error" : "rsvp-message rsvp-message--success"
    this.messageTarget.style.display = "block"
  }
}
