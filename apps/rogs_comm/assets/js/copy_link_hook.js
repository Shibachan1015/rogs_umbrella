const CopyLinkHook = {
  mounted() {
    this.handleClick = this.handleClick.bind(this)
    this.resetTimer = null
    this.originalText =
      this.el.querySelector("[data-copy-label]")?.textContent?.trim() ||
      this.el.dataset.originalText ||
      "リンクをコピー"

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
    if (this.resetTimer) clearTimeout(this.resetTimer)
  },

  handleClick(event) {
    event.preventDefault()

    const url = this.el.dataset.copyUrl || window.location.href
    const label = this.el.querySelector("[data-copy-label]")
    const feedback = this.el.querySelector("[data-copy-feedback]")

    const setCopiedState = message => {
      if (label) {
        label.textContent = message
      }
      if (feedback) {
        feedback.textContent = message
      }
      this.el.classList.add("state-pill--glow")

      if (this.resetTimer) clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => {
        if (label) {
          label.textContent = this.originalText
        }
        if (feedback) {
          feedback.textContent = ""
        }
        this.el.classList.remove("state-pill--glow")
      }, 2000)
    }

    if (!navigator?.clipboard) {
      setCopiedState("コピーできませんでした")
      return
    }

    navigator.clipboard
      .writeText(url)
      .then(() => setCopiedState("リンクをコピーしました"))
      .catch(() => setCopiedState("コピーできませんでした"))
  },
}

export default CopyLinkHook

