const TypingHook = {
  mounted() {
    this.roomId = this.el.dataset.roomId
    this.socket = window.realtimeSocket

    if (!this.socket) {
      console.warn("[TypingHook] Realtime socket not found")
      return
    }

    // Join channel for typing events
    this.channel = this.socket.channel(`room:${this.roomId}`, {})
    this.channel.join().receive("error", err => {
      console.error("[TypingHook] Channel join error", err)
    })

    // Find input field
    this.inputEl = this.el.querySelector('input[name="content"]')
    if (!this.inputEl) return

    // Track typing state
    this.isTyping = false
    this.typingTimeout = null

    // Handle input events
    this.inputEl.addEventListener("input", () => {
      if (!this.isTyping) {
        this.isTyping = true
        this.channel.push("typing_start", {})
      }

      // Reset timeout
      clearTimeout(this.typingTimeout)
      this.typingTimeout = setTimeout(() => {
        if (this.isTyping) {
          this.isTyping = false
          this.channel.push("typing_stop", {})
        }
      }, 3000)
    })

    // Stop typing on blur
    this.inputEl.addEventListener("blur", () => {
      if (this.isTyping) {
        this.isTyping = false
        this.channel.push("typing_stop", {})
      }
      clearTimeout(this.typingTimeout)
    })
  },

  destroyed() {
    if (this.typingTimeout) {
      clearTimeout(this.typingTimeout)
    }
    if (this.isTyping) {
      this.channel?.push("typing_stop", {})
    }
    this.channel?.leave()
  }
}

export default TypingHook

