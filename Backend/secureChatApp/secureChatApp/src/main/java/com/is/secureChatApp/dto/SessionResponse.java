package com.is.secureChatApp.dto;

import java.time.Instant;

public record SessionResponse(
        String sessionId,
        String username,
        String peerUsername,
        Instant createdAt,
        Instant expiresAt,
        String status
) {
}