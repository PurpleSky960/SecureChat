
package com.is.secureChatApp.dto;

import java.time.Instant;

public record PublicKeyResponse(
        String username,
        String publicKey,
        String algorithm,
        String fingerprint,
        Instant createdAt,
        String status
) {
}
