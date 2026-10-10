
package com.is.secureChatApp.websocket;

import tools.jackson.databind.ObjectMapper;
import com.is.secureChatApp.dto.SecureMessagePacket;
import com.is.secureChatApp.service.MessageRelayService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;

@Component
@RequiredArgsConstructor
public class MessageHandler extends TextWebSocketHandler {

    private final ConnectedClientRegistry clientRegistry;
    private final MessageRelayService relayService;
    private final ObjectMapper objectMapper;

    @Override
    public void afterConnectionEstablished(
            WebSocketSession session
    ) throws IOException {

        String username = extractUsername(session);

        if (username == null ||
                !username.matches("[a-z0-9_]{3,50}")) {

            session.sendMessage(new TextMessage(
                    "{\"type\":\"ERROR\",\"message\":\"A valid username is required\"}"
            ));

            session.close(CloseStatus.BAD_DATA);
            return;
        }

        // DEVELOPMENT ONLY:
        // This username is supplied in the WebSocket URL.
        // TODO (Authentication integration):
        // Obtain the username from the authenticated principal
        // instead of trusting a query parameter.

        clientRegistry.register(username, session);

        System.out.println(
                "Connected user: " + username +
                        " | Session: " + session.getId()
        );

        sendStatus(
                session,
                "CONNECTED",
                "WebSocket connected as " + username
        );
    }

    private String extractUsername(WebSocketSession session) {
        if (session.getUri() == null ||
                session.getUri().getQuery() == null) {
            return null;
        }

        String query = session.getUri().getQuery();

        for (String parameter : query.split("&")) {
            String[] parts = parameter.split("=", 2);

            if (parts.length == 2 &&
                    parts[0].equals("username")) {

                try {
                    return URLDecoder.decode(
                            parts[1],
                            StandardCharsets.UTF_8
                    ).trim().toLowerCase(
                            java.util.Locale.ROOT
                    );
                } catch (IllegalArgumentException e) {
                    return null;
                }
            }
        }

        return null;
    }

    @Override
    protected void handleTextMessage(
            WebSocketSession session,
            TextMessage message
    ) throws IOException {

        try {
            SecureMessagePacket packet =
                    objectMapper.readValue(
                            message.getPayload(),
                            SecureMessagePacket.class
                    );

            validatePacket(packet, session);

            relayService.relay(packet);

            sendStatus(
                    session,
                    "RELAYED",
                    "Packet delivered to recipient"
            );

        } catch (IllegalArgumentException e) {
            sendStatus(session, "ERROR", e.getMessage());

        } catch (tools.jackson.core.JacksonException e) {
            sendStatus(
                    session,
                    "ERROR",
                    "Malformed secure message packet"
            );
        }
    }

    private void validatePacket(
            SecureMessagePacket packet,
            WebSocketSession session
    ) {
        if (packet.messageId() == null ||
                packet.messageId().isBlank() ||
                packet.messageId().length() > 100) {
            throw new IllegalArgumentException(
                    "Invalid message ID"
            );
        }

        if (packet.senderUsername() == null ||
                packet.recipientUsername() == null ||
                packet.sessionId() == null ||
                packet.nonce() == null ||
                packet.ciphertext() == null ||
                packet.hmac() == null ||
                packet.signature() == null ||
                packet.timestamp() == null) {
            throw new IllegalArgumentException(
                    "Required packet fields are missing"
            );
        }

        if (packet.ciphertext().isBlank() ||
                packet.ciphertext().length() > 100_000) {
            throw new IllegalArgumentException(
                    "Invalid ciphertext length"
            );
        }

        String connectedUsername =
                clientRegistry.getUsername(session.getId());

        if (connectedUsername == null ||
                !connectedUsername.equals(
                        packet.senderUsername()
                                .toLowerCase(
                                        java.util.Locale.ROOT
                                )
                )) {
            throw new IllegalArgumentException(
                    "Sender does not match connected user"
            );
        }

        if (!packet.recipientUsername().matches(
                "[a-zA-Z0-9_]{3,50}"
        )) {
            throw new IllegalArgumentException(
                    "Invalid recipient username"
            );
        }

        Instant now = Instant.now();

        if (packet.timestamp().isBefore(
                now.minusSeconds(300)
        ) ||
                packet.timestamp().isAfter(
                        now.plusSeconds(60)
                )) {
            throw new IllegalArgumentException(
                    "Message timestamp is outside the allowed window"
            );
        }

        // TODO (Python security integration):
        // The receiver's crypto layer will verify the HMAC
        // and digital signature before accepting plaintext.
        // This server only validates the packet envelope.
        //
        // TODO (Security hardening):
        // Implement persistent or distributed replay detection
        // keyed by authenticated sender + message ID/nonce.
        // Timestamp validation alone does NOT prevent replay.
    }

    private void sendStatus(
            WebSocketSession session,
            String type,
            String message
    ) throws IOException {

        if (!session.isOpen()) {
            return;
        }

        String json = objectMapper.writeValueAsString(
                java.util.Map.of(
                        "type", type,
                        "message", message
                )
        );

        synchronized (session) {
            if (session.isOpen()) {
                session.sendMessage(new TextMessage(json));
            }
        }
    }

    @Override
    public void afterConnectionClosed(
            WebSocketSession session,
            CloseStatus status
    ) {
        clientRegistry.unregister(session);

        System.out.println(
                "Disconnected session: " + session.getId() +
                        " | Remaining clients: " +
                        clientRegistry.getConnectedClientCount()
        );
    }

    @Override
    public void handleTransportError(
            WebSocketSession session,
            Throwable exception
    ) {
        clientRegistry.unregister(session);

        System.err.println(
                "WebSocket transport error: " +
                        exception.getMessage()
        );

        try {
            if (session.isOpen()) {
                session.close(CloseStatus.SERVER_ERROR);
            }
        } catch (IOException e) {
            System.err.println(
                    "Failed to close session: " + e.getMessage()
            );
        }
    }
}
