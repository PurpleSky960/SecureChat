
package com.is.secureChatApp.websocket;

import tools.jackson.databind.ObjectMapper;
import tools.jackson.core.JacksonException;

import com.is.secureChatApp.dto.SecureMessagePacket;
import com.is.secureChatApp.service.MessagePersistenceService;
import com.is.secureChatApp.service.MessageRelayService;

import lombok.RequiredArgsConstructor;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;

@Component
@RequiredArgsConstructor
public class MessageHandler extends TextWebSocketHandler {

    private final ConnectedClientRegistry clientRegistry;
    private final MessageRelayService relayService;
    private final MessagePersistenceService persistenceService;
    private final ObjectMapper objectMapper;

    @Override
    public void afterConnectionEstablished(
            WebSocketSession session
    ) throws IOException {

        Object authenticatedIdentity =
                session.getAttributes().get("authenticatedUsername");

        if (!(authenticatedIdentity instanceof String username)
                || username.isBlank()) {

            session.close(CloseStatus.NOT_ACCEPTABLE);
            return;
        }

        username = username.trim().toLowerCase(Locale.ROOT);

        if (!username.matches("[a-z0-9_]{3,50}")) {
            session.close(CloseStatus.BAD_DATA);
            return;
        }

        clientRegistry.register(username, session);

        System.out.println(
                "Authenticated WebSocket user: " + username
                        + " | Session: " + session.getId()
        );

        sendStatus(
                session,
                "CONNECTED",
                "WebSocket authenticated as " + username
        );
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

            // Validate packet structure and authenticated sender.
            validatePacket(packet, session);

            // Check recipient availability BEFORE persistence.
            String recipientUsername =
                    packet.recipientUsername()
                            .trim()
                            .toLowerCase(Locale.ROOT);

            if (clientRegistry.getSession(recipientUsername) == null) {
                throw new IllegalArgumentException(
                        "Recipient is not connected"
                );
            }

            // Validate database references and persist encrypted data.
            persistenceService.persist(packet);

            // Relay the unchanged encrypted packet.
            relayService.relay(packet);

            sendStatus(
                    session,
                    "RELAYED",
                    "Packet delivered to recipient"
            );

        } catch (IllegalArgumentException e) {

            sendStatus(
                    session,
                    "ERROR",
                    e.getMessage()
            );

        } catch (JacksonException e) {

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

        if (packet.messageId() == null
                || packet.messageId().isBlank()
                || packet.messageId().length() > 100) {

            throw new IllegalArgumentException(
                    "Invalid message ID"
            );
        }

        if (packet.senderUsername() == null
                || packet.recipientUsername() == null
                || packet.sessionId() == null
                || packet.nonce() == null
                || packet.ciphertext() == null
                || packet.hmac() == null
                || packet.signature() == null
                || packet.timestamp() == null) {

            throw new IllegalArgumentException(
                    "Required packet fields are missing"
            );
        }

        if (packet.ciphertext().isBlank()
                || packet.ciphertext().length() > 100_000) {

            throw new IllegalArgumentException(
                    "Invalid ciphertext length"
            );
        }

        if (packet.nonce().isBlank()
                || packet.sessionId().isBlank()
                || packet.hmac().isBlank()
                || packet.signature().isBlank()) {

            throw new IllegalArgumentException(
                    "Invalid cryptographic packet fields"
            );
        }

        String connectedUsername =
                clientRegistry.getUsername(session.getId());

        String packetSender =
                packet.senderUsername().trim().toLowerCase(Locale.ROOT);

        if (connectedUsername == null
                || !connectedUsername.equals(packetSender)) {

            throw new IllegalArgumentException(
                    "Sender does not match connected user"
            );
        }

        String recipientUsername =
                packet.recipientUsername().trim();

        if (!recipientUsername.matches("[a-zA-Z0-9_]{3,50}")) {
            throw new IllegalArgumentException(
                    "Invalid recipient username"
            );
        }

        Instant now = Instant.now();

        if (packet.timestamp().isBefore(now.minusSeconds(300))
                || packet.timestamp().isAfter(now.plusSeconds(60))) {

            throw new IllegalArgumentException(
                    "Message timestamp is outside the allowed window"
            );
        }

        // HMAC and RSA-PSS verification are performed by the
        // receiving client's cryptographic layer.
        //
        // Replay protection is enforced by MessagePersistenceService
        // using persistent message ID and nonce checks.
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
                Map.of(
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
                "Disconnected session: " + session.getId()
                        + " | Remaining clients: "
                        + clientRegistry.getConnectedClientCount()
        );
    }

    @Override
    public void handleTransportError(
            WebSocketSession session,
            Throwable exception
    ) {

        clientRegistry.unregister(session);

        System.err.println(
                "WebSocket transport error: "
                        + exception.getMessage()
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
