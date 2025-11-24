const ChatScrollHook = {
  mounted() {
    this.messagesEl = document.getElementById("messages")
    if (!this.messagesEl) return

    // Scroll to bottom on mount
    this.scrollToBottom()

    // Observe for new messages
    this.observer = new MutationObserver(() => {
      // Only auto-scroll if user is near bottom
      const isNearBottom = this.isNearBottom()
      if (isNearBottom) {
        this.scrollToBottom()
      }
    })

    this.observer.observe(this.messagesEl, {
      childList: true,
      subtree: true,
    })
  },

  updated() {
    // Scroll to bottom when new messages are added via LiveView update
    if (this.messagesEl) {
      const isNearBottom = this.isNearBottom()
      if (isNearBottom) {
        setTimeout(() => this.scrollToBottom(), 100)
      }
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  },

  scrollToBottom() {
    if (this.messagesEl) {
      this.messagesEl.scrollTop = this.messagesEl.scrollHeight
    }
  },

  isNearBottom() {
    if (!this.messagesEl) return true
    const threshold = 200 // pixels from bottom
    return (
      this.messagesEl.scrollHeight -
        this.messagesEl.scrollTop -
        this.messagesEl.clientHeight <
      threshold
    )
  },
}

export default ChatScrollHook

