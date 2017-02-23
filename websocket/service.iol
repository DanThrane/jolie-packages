// The WebSocket service interface
type SocketInitializeMessage: void {
    .port?: int
    .host?: string
    .path?: string
    .serializeAs?: string
}

type SocketSendToAllMessage: undefined

type SocketSendToChannelMessage: void {
    .channel: long
    .message: undefined
}

interface IWebSocket {
    RequestResponse:
        initialize(SocketInitializeMessage)(void),
        stop(void)(void),
        sendToAll(SocketSendToAllMessage)(void),
        sendToChannel(SocketSendToChannelMessage)(void)
}

outputPort WebSocket {
    Interfaces: IWebSocket
}

embedded {
    Java:
        "dk.thrane.websocket.WebSocketService" in WebSocket
}
