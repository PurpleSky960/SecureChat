
package com.is.secureChatApp.websocket;

import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketSession;

import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class ConnectedClientRegistry {

    private final Map<String, WebSocketSession> sessionsByUsername =
            new ConcurrentHashMap<>();

    private final Map<String, String> usernamesBySessionId =
            new ConcurrentHashMap<>();

    public void register(
            String username,
            WebSocketSession session
    ) {

        // Normalize the identity established by the authenticated
        // WebSocket handshake.
        String normalizedUsername =
                username.trim().toLowerCase(Locale.ROOT);

        WebSocketSession previous =
                sessionsByUsername.put(normalizedUsername, session);

        usernamesBySessionId.put(
                session.getId(),
                normalizedUsername
        );

        // If the same user reconnects, close the old connection.
        if (previous != null
                && !previous.getId().equals(session.getId())) {

            usernamesBySessionId.remove(previous.getId());

            try {
                if (previous.isOpen()) {
                    previous.close();
                }
            } catch (Exception e) {
                System.err.println(
                        "Could not close previous session: "
                                + e.getMessage()
                );
            }
        }
    }

    public WebSocketSession getSession(String username) {

        String normalizedUsername =
                username.trim().toLowerCase(Locale.ROOT);

        WebSocketSession session =
                sessionsByUsername.get(normalizedUsername);

        if (session == null || !session.isOpen()) {
            return null;
        }

        return session;
    }

    public String getUsername(String sessionId) {
        return usernamesBySessionId.get(sessionId);
    }

    public void unregister(WebSocketSession session) {

        String username =
                usernamesBySessionId.remove(session.getId());

        if (username != null) {

            // Do not remove a newer connection for the same user.
            sessionsByUsername.remove(username, session);
        }
    }

    public int getConnectedClientCount() {
        return sessionsByUsername.size();
    }
}
