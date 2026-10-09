
package com.is.secureChatApp.dto;

public record AuthResponse(
        String message,
        Long userId,
        String username
) {
}
