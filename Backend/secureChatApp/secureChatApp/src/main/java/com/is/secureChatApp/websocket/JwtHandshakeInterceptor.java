package com.is.secureChatApp.websocket;

import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.Map;
import java.security.Principal;

@Component
public class JwtHandshakeInterceptor implements HandshakeInterceptor {

    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes
    ) {

        Principal principal = request.getPrincipal();

        if (!(principal instanceof Authentication authentication)
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {

            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        String username = authentication.getName();

        if (username == null || username.isBlank()) {
            response.setStatusCode(HttpStatus.UNAUTHORIZED);
            return false;
        }

        // Store only the identity authenticated by Spring Security.
        attributes.put("authenticatedUsername", username);

        return true;
    }

    @Override
    public void afterHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Exception exception
    ) {
        // No post-handshake processing required.
    }
}