package com.is.secureChatApp.dto;

import jakarta.validation.constraints.NotBlank;

public record CreateSessionRequest(
        @NotBlank String peerUsername
) {}