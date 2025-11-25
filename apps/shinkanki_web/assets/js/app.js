// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Chat scroll hook for auto-scrolling to new messages
const ChatScroll = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    const container = this.el
    container.scrollTop = container.scrollHeight
  }
}

// Toast auto-remove hook
const ToastAutoRemove = {
  mounted() {
    setTimeout(() => {
      this.el.classList.add("animate-slide-out-right")
      setTimeout(() => {
        this.el.remove()
      }, 300)
    }, 5000)
  }
}

const clamp = (value, min, max) => Math.min(Math.max(value, min), max)

// Chat input hook for Enter key handling
const ChatInput = {
  mounted() {
    this.handleKeyDown = (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest("form")
        if (form) {
          const submitEvent = new Event("submit", { bubbles: true, cancelable: true })
          form.dispatchEvent(submitEvent)
        }
      }
    }
    this.el.addEventListener("keydown", this.handleKeyDown)
  },
  destroyed() {
    if (this.handleKeyDown) {
      this.el.removeEventListener("keydown", this.handleKeyDown)
    }
  }
}

const AmbientAudio = {
  mounted() {
    const src = this.el.dataset.audioSrc
    if (!src) return

    this.slider = this.el.querySelector("[data-role='volume-slider']")
    this.muteBtn = this.el.querySelector("[data-role='mute-toggle']")
    this.label = this.el.querySelector("[data-role='volume-label']")
    this.meter = this.el.querySelector("[data-role='volume-meter']")
    this.panel = this.el.querySelector("[data-role='control-panel']")
    this.gearToggle = this.el.querySelector("[data-role='gear-toggle']")

    const initialVolume = clamp(parseFloat(this.el.dataset.initialVolume || "0.4"), 0, 1)
    this.lastVolume = initialVolume
    this.audio = new Audio(src)
    this.audio.loop = true
    this.audio.preload = "auto"
    this.audio.volume = initialVolume

    const attemptPlay = () => {
      const playPromise = this.audio.play()
      if (playPromise) {
        playPromise
          .then(() => {
            this.el.classList.remove("requires-interaction")
          })
          .catch(() => {
            this.el.classList.add("requires-interaction")
          })
      }
    }

    this.audio.addEventListener("canplay", attemptPlay, {once: true})
    this.interactionHandlers = ["pointerdown", "touchstart", "keydown"].map((eventName) => {
      const handler = () => {
        attemptPlay()
        window.removeEventListener(eventName, handler)
      }
      window.addEventListener(eventName, handler)
      return {eventName, handler}
    })

    if (this.slider) {
      this.slider.value = Math.round(initialVolume * 100)
      this.handleVolumeInput = (event) => {
        const value = clamp(parseFloat(event.target.value || "0") / 100, 0, 1)
        this.lastVolume = value > 0 ? value : this.lastVolume
        this.audio.volume = value
        if (this.audio.muted && value > 0) {
          this.audio.muted = false
        }
        attemptPlay()
        this.updateUI()
      }
      this.slider.addEventListener("input", this.handleVolumeInput)
    }

    if (this.muteBtn) {
      this.handleMuteToggle = () => {
        if (this.audio.muted || this.audio.volume === 0) {
          this.audio.muted = false
          const restored = this.lastVolume > 0 ? this.lastVolume : 0.3
          this.audio.volume = restored
          if (this.slider) this.slider.value = Math.round(restored * 100)
        } else {
          this.audio.muted = true
        }
        attemptPlay()
        this.updateUI()
      }
      this.muteBtn.addEventListener("click", this.handleMuteToggle)
    }

    if (this.gearToggle) {
      this.handleGearToggle = (event) => {
        event.stopPropagation()
        const willOpen = !this.el.classList.contains("panel-open")
        this.setPanelState(willOpen)
      }
      this.handleOutsideClick = (event) => {
        if (!this.el.contains(event.target)) {
          this.setPanelState(false)
        }
      }
      this.gearToggle.addEventListener("click", this.handleGearToggle)
      document.addEventListener("click", this.handleOutsideClick)
    }

    this.updateUI()
  },
  setPanelState(open) {
    if (open) {
      this.el.classList.add("panel-open")
      this.gearToggle?.setAttribute("aria-expanded", "true")
    } else {
      this.el.classList.remove("panel-open")
      this.gearToggle?.setAttribute("aria-expanded", "false")
    }
  },
  updateUI() {
    const effectiveVolume = this.audio && this.audio.muted ? 0 : Math.round((this.audio?.volume || 0) * 100)
    if (this.label) {
      this.label.textContent = `${effectiveVolume}%`
    }
    if (this.meter) {
      this.meter.style.setProperty("--audio-volume", `${effectiveVolume}%`)
    }
    if (this.muteBtn) {
      const isMuted = this.audio?.muted || effectiveVolume === 0
      this.muteBtn.setAttribute("aria-pressed", isMuted ? "true" : "false")
      this.muteBtn.classList.toggle("is-muted", isMuted)
    }
    this.el.classList.toggle("is-muted", this.audio?.muted)
  },
  destroyed() {
    if (this.slider && this.handleVolumeInput) {
      this.slider.removeEventListener("input", this.handleVolumeInput)
    }
    if (this.muteBtn && this.handleMuteToggle) {
      this.muteBtn.removeEventListener("click", this.handleMuteToggle)
    }
    if (this.audio) {
      this.audio.pause()
      this.audio.src = ""
      this.audio = null
    }
    if (this.interactionHandlers) {
      this.interactionHandlers.forEach(({eventName, handler}) => {
        window.removeEventListener(eventName, handler)
      })
    }
    if (this.gearToggle && this.handleGearToggle) {
      this.gearToggle.removeEventListener("click", this.handleGearToggle)
    }
    if (this.handleOutsideClick) {
      document.removeEventListener("click", this.handleOutsideClick)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ChatScroll, ToastAutoRemove, ChatInput, AmbientAudio},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Navbar scroll effect
document.addEventListener("DOMContentLoaded", () => {
  const navbar = document.getElementById("navbar")
  if (navbar) {
    let lastScroll = 0
    window.addEventListener("scroll", () => {
      const currentScroll = window.pageYOffset
      if (currentScroll > 50) {
        navbar.classList.add("scrolled")
      } else {
        navbar.classList.remove("scrolled")
      }
      lastScroll = currentScroll
    })
  }
})

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

