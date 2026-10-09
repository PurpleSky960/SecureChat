
package com.is.secureChatApp.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterPublicKeyRequest(

        @NotBlank(message = "Username is required")
        @Size(max = 50)
        String username,

        @NotBlank(message = "Public key is required")
        @Size(max = 8192)
        String publicKey

) {
}
