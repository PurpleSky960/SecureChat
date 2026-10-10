
package com.is.secureChatApp.dto;

import java.time.Instant;

public record SecureMessagePacket(
        String messageId,
        String senderUsername,
        String recipientUsername,
        String sessionId,
        Instant timestamp,
        String nonce,
        String ciphertext,
        String hmac,
        String signature
) {
}
