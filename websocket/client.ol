include "console.iol"
include "string_utils.iol"

include "service.iol"
include "client.iol"
include "time.iol"
include "exec.iol"

execution { concurrent }

inputPort WebSocketClient {
    Interfaces: IWebSocketClient
    Location: "local"
    Protocol: sodep
}

init {
    scope(s) {
        install(WebSocketFault =>
            valueToPrettyString@StringUtils(s.WebSocketFault)(prettyFault);
            println@Console("WebSocketFault:")();
            println@Console(prettyFault)()
        );
        println@Console("Hello, world!")();
        initialize@WebSocket({ .serializeAs = "text" })();
        println@Console("WebSocket server started!")();

        i = 0;
        while (true) {
            exec@Exec("figlet" { .args[0] = "" + i })(result);
            println@Console(result)();
            i++;
            println@Console("New message in console!")();
            sendToAll@WebSocket(result)();
            sleep@Time(1000)()
        }
    }
}

main {
    [onWebSocketConnect(req)() {
        println@Console("Received a callback on onWebSocketConnect")();
        println@Console("Got the following message:")();
        valueToPrettyString@StringUtils(req)(prettyReq);
        println@Console(prettyReq)()
    }]

    [onWebSocketMessage(req)() {
        println@Console("Received a callback on onWebSocketMessage")();
        println@Console("Got the following message:")();
        valueToPrettyString@StringUtils(req)(prettyReq);
        println@Console(prettyReq)()
    }]

    [onWebSocketClose(req)() {
        println@Console("Received a callback on onWebSocketClose")();
        println@Console("Got the following message:")();
        valueToPrettyString@StringUtils(req)(prettyReq);
        println@Console(prettyReq)()
    }]
}

