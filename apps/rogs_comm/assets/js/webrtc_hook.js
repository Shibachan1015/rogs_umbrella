import ChatRealtime from "./chat_channel"

const WebRTCHook = {
  mounted() {
    this.roomId = this.el.dataset.roomId
    this.peer = null

    try {
      this.channel = ChatRealtime.joinSignal(this.roomId, {
        offer: payload => this.handleOffer(payload),
        answer: payload => this.handleAnswer(payload),
        "ice-candidate": payload => this.handleCandidate(payload),
      })
    } catch (error) {
      console.error("[WebRTC Hook] failed to join signal channel", error)
    }

    this.handleEvent("rtc:start", payload => this.startCall(payload))
    this.handleEvent("rtc:stop", payload => this.stopCall(payload))
    this.handleEvent("rtc:toggle-mic", payload => this.toggleMic(payload))
    this.handleEvent("rtc:toggle-speakers", payload => this.toggleSpeakers(payload))
  },

  handleOffer(payload) {
    this.log("offer", payload)
  },

  handleAnswer(payload) {
    this.log("answer", payload)
  },

  handleCandidate(payload) {
    this.log("candidate", payload)
  },

  startCall(payload) {
    this.log("start-call", payload)
    this.channel?.push("peer-ready", {
      room_id: this.roomId,
      action: "start",
      timestamp: Date.now(),
    })
  },

  stopCall(payload) {
    this.log("stop-call", payload)
    this.channel?.push("peer-ready", {
      room_id: this.roomId,
      action: "stop",
      timestamp: Date.now(),
    })
  },

  toggleMic(payload) {
    this.log("toggle-mic", payload)
  },

  toggleSpeakers(payload) {
    this.log("toggle-speakers", payload)
  },

  log(label, payload) {
    console.debug(`[WebRTC Hook] ${label}`, payload)
  },

  destroyed() {
    this.channel?.leave()
    this.channel = null
  },
}

export default WebRTCHook


