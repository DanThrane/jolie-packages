// The WebSocket client interface
type SocketConnectMessage: void {
    .channel: long
    .requestURI: string
}

type SocketIncomingMessage: void {
    .channel: long
    .data: undefined
}

type SocketOnCloseMessage: void {
    .channel: long
    .reason: string
    .code: int
}

interface IWebSocketClient {
    RequestResponse:
        onWebSocketConnect(SocketConnectMessage)(void),
        onWebSocketMessage(SocketIncomingMessage)(void),
        onWebSocketClose(SocketOnCloseMessage)(void),
}
