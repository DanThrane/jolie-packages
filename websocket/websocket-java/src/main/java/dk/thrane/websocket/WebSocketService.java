package dk.thrane.websocket;

import io.undertow.Undertow;
import io.undertow.websockets.core.AbstractReceiveListener;
import io.undertow.websockets.core.BufferedTextMessage;
import io.undertow.websockets.core.WebSocketChannel;
import io.undertow.websockets.core.WebSockets;
import io.undertow.websockets.spi.WebSocketHttpExchange;
import jolie.net.CommMessage;
import jolie.runtime.FaultException;
import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.embedding.RequestResponse;
import joliex.util.JsonUtilsService;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

import static io.undertow.Handlers.path;
import static io.undertow.Handlers.websocket;

public class WebSocketService extends JavaService {
    public static final String FAULT_NAME = "WebSocketFault";
    private final AtomicLong channelId = new AtomicLong(0);
    private final Map<Long, WebSocketChannel> connectedChannels = new HashMap<>();
    private final Map<WebSocketChannel, Long> reverseConnectedChannels = new HashMap<>();
    private final Object channelsLock = new Object();
    private final Object serverLock = new Object();
    private Undertow server = null;
    private SerializationType type = null;
    private JsonUtilsService jsonUtilsService = new JsonUtilsService();

    public static enum SerializationType {
        TEXT("text"),
        JSON("json");
        private final String name;

        SerializationType(String name) {
            this.name = name;
        }

        public static SerializationType fromString(String name) {
            return Arrays.stream(values()).filter(it -> it.name.equals(name)).findFirst().orElse(null);
        }
    }

    @RequestResponse
    public void initialize(Value request) throws FaultException {
        synchronized (serverLock) {
            if (server != null) {
                System.out.println(1);
                throw new FaultException(FAULT_NAME, "Server is already running!");
            }

            int port = optionalValue(request, "port", 8080);
            String host = optionalValue(request, "host", "localhost");
            String pathPrefix = optionalValue(request, "path", "/");
            String serializationType = optionalValue(request, "serializeAs", "text");
            type = SerializationType.fromString(serializationType);
            if (type == null) {
                System.out.println(2);
                throw new FaultException(FAULT_NAME, "Bad serialization type: '" + serializationType + "'");
            }

            server = Undertow.builder()
                    .addHttpListener(port, host)
                    .setHandler(
                            path().addPrefixPath(pathPrefix, websocket(this::onConnect))
                    ).build();
        }
        server.start();
    }

    @RequestResponse
    public void stop() throws FaultException {
        synchronized (serverLock) {
            if (server == null) {
                throw new FaultException(FAULT_NAME, "Server isn't running");
            }

            server.stop();
            server = null;
        }
    }

    @RequestResponse
    public void sendToAll(Value message) throws FaultException {
        synchronized (channelsLock) {
            final String messageString = serializeMessage(message);
            connectedChannels.forEach(((id, channel) ->
                    WebSockets.sendText(messageString, channel, null))
            );
        }
    }

    @RequestResponse
    public void sendToChannel(Value message) throws FaultException {
        long channelId = message.getFirstChild("channel").longValue();
        WebSocketChannel channel = connectedChannels.get(channelId);
        if (channel == null) {
            throw new FaultException(FAULT_NAME, "Unknown channel");
        }
        WebSockets.sendText(serializeMessage(message.getFirstChild("message")), channel, null);
    }

    private String serializeMessage(Value message) throws FaultException {
        String messageString = null;
        switch (type) {
            case JSON:
                messageString = jsonUtilsService.getJsonString(message).strValue();
                break;
            case TEXT:
                messageString = message.strValue();
                break;

        }
        return messageString;
    }

    private void onConnect(WebSocketHttpExchange exchange, WebSocketChannel channel) {
        String requestURI = exchange.getRequestURI();
        long id = channelId.getAndIncrement();
        synchronized (channelsLock) {
            connectedChannels.put(id, channel);
            reverseConnectedChannels.put(channel, id);
        }

        Value connectedMessage = Value.create();
        connectedMessage.getFirstChild("requestURI").setValue(requestURI);
        connectedMessage.getFirstChild("channel").setValue(id);
        sendMessage(CommMessage.createRequest("onWebSocketConnect", "/", connectedMessage));

        channel.getCloseSetter().set(channel1 -> onClose(channel, channel.getCloseReason(), channel.getCloseCode()));
        channel.getReceiveSetter().set(new AbstractReceiveListener() {
            @Override
            protected void onFullTextMessage(WebSocketChannel channel, BufferedTextMessage message) throws IOException {
                try {
                    onMessage(channel, message);
                } catch (FaultException ignored) {}
            }
        });
        channel.resumeReceives();
    }

    private void onMessage(WebSocketChannel channel, BufferedTextMessage message) throws FaultException {
        if (!reverseConnectedChannels.containsKey(channel)) {
            return; // Silently discard the message
        }

        Value val = null;
        switch (type) {
            case JSON:
                val = jsonUtilsService.getJsonValue(Value.create(message.getData()));
                break;
            case TEXT:
                val = Value.create(message.getData());
                break;
        }
        Value requestMessage = Value.create();
        requestMessage.getFirstChild("data").deepCopy(val);
        requestMessage.getFirstChild("channel").setValue(reverseConnectedChannels.get(channel));

        sendMessage(CommMessage.createRequest("onWebSocketMessage", "/", requestMessage));
    }

    private void onClose(WebSocketChannel channel, String reason, int code) {
        Long id;
        synchronized (channelsLock) {
            id = reverseConnectedChannels.remove(channel);
            connectedChannels.remove(id);
        }

        Value closeMessage = Value.create();
        closeMessage.getFirstChild("channel").setValue(id);
        closeMessage.getFirstChild("reason").setValue(reason);
        closeMessage.getFirstChild("code").setValue(code);
        sendMessage(CommMessage.createRequest("onWebSocketClose", "/", closeMessage));
    }

    private <T> T optionalValue(Value request, String key, T defaultValue) {
        if (request.hasChildren(key)) {
            //noinspection unchecked
            return (T) request.getFirstChild(key).valueObject();
        } else {
            return defaultValue;
        }
    }
}
