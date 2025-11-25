const ChatStateHook = {
  mounted() {
    this.previousSearchMode = this.el.dataset.searchMode || "off"
    this.previousRtcState = this.el.dataset.rtcState || "idle"
  },

  updated() {
    const currentSearchMode = this.el.dataset.searchMode || "off"
    const currentRtcState = this.el.dataset.rtcState || "idle"

    if (currentSearchMode !== this.previousSearchMode) {
      this.flashPill("search")
      this.previousSearchMode = currentSearchMode
    }

    if (currentRtcState !== this.previousRtcState) {
      this.flashPill("audio")
      this.previousRtcState = currentRtcState
    }
  },

  flashPill(target) {
    const selector =
      target === "search"
        ? "[data-pill=\"search\"]"
        : "[data-pill=\"audio\"]"

    const pill = this.el.querySelector(selector)

    if (!pill) return

    const animationClass =
      target === "search" ? "state-pill--pulse" : "state-pill--glow"

    pill.classList.remove(animationClass)
    pill.offsetHeight // force reflow so animation can restart
    pill.classList.add(animationClass)

    setTimeout(() => {
      pill.classList.remove(animationClass)
    }, 700)
  },
}

export default ChatStateHook

