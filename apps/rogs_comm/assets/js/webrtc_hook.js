import ChatRealtime from "./chat_channel"

const WebRTCHook = {
  mounted() {
    this.roomId = this.el.dataset.roomId
    this.peer = null

    ChatRealtime.joinSignal(this.roomId, {
      offer: payload => this.handleOffer(payload),
      answer: payload => this.handleAnswer(payload),
      "ice-candidate": payload => this.handleCandidate(payload),
    })
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

  log(label, payload) {
    console.debug(`[WebRTC Hook] ${label}`, payload)
  },
}

export default WebRTCHook


