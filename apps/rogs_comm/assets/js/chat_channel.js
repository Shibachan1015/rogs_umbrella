import {Socket} from "phoenix"

const ChatRealtime = (() => {
  let socket

  function connect(csrfToken) {
    if (socket) return socket
    socket = new Socket("/socket", {params: {_csrf_token: csrfToken}})
    socket.connect()
    window.realtimeSocket = socket
    return socket
  }

  function joinChat(roomId, hooks = {}) {
    if (!socket) throw new Error("Realtime socket not initialized")
    const channel = socket.channel(`room:${roomId}`, {})
    channel.join().receive("error", err => console.error("[ChatChannel] join error", err))
    channel.on("new_message", payload => console.debug("[ChatChannel] new_message", payload))
    if (hooks.message) channel.on("new_message", hooks.message)
    return channel
  }

  function joinSignal(roomId, hooks = {}) {
    if (!socket) throw new Error("Realtime socket not initialized")
    const channel = socket.channel(`signal:${roomId}`, {})
    channel.join().receive("error", err => console.error("[SignalChannel] join error", err))
    for (const event of ["offer", "answer", "ice-candidate"]) {
      channel.on(event, payload => {
        console.debug(`[SignalChannel] ${event}`, payload)
        hooks[event]?.(payload)
      })
    }
    return channel
  }

  return {connect, joinChat, joinSignal}
})()

export default ChatRealtime


