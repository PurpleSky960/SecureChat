package com.is.secureChatApp.controller;

import com.is.secureChatApp.dto.CreateSessionRequest;
import com.is.secureChatApp.dto.SessionResponse;
import com.is.secureChatApp.service.SessionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/sessions")
@RequiredArgsConstructor
public class SessionController {

    private final SessionService sessionService;

    @PostMapping
    public ResponseEntity<SessionResponse> createSession(
            @Valid @RequestBody CreateSessionRequest request,
            Authentication authentication
    ) {
        SessionResponse response = sessionService.createSession(
                authentication.getName(),
                request
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping
    public ResponseEntity<List<SessionResponse>> getMySessions(
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                sessionService.getMySessions(authentication.getName())
        );
    }

    @GetMapping("/{sessionId}")
    public ResponseEntity<SessionResponse> getSession(
            @PathVariable String sessionId,
            Authentication authentication
    ) {
        return ResponseEntity.ok(
                sessionService.getSession(
                        authentication.getName(),
                        sessionId
                )
        );
    }

    @DeleteMapping("/{sessionId}")
    public ResponseEntity<Void> terminateSession(
            @PathVariable String sessionId,
            Authentication authentication
    ) {
        sessionService.terminateSession(
                authentication.getName(),
                sessionId
        );

        return ResponseEntity.noContent().build();
    }
}