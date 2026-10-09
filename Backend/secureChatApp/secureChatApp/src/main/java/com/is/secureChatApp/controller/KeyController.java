
package com.is.secureChatApp.controller;

import com.is.secureChatApp.dto.PublicKeyResponse;
import com.is.secureChatApp.dto.RegisterPublicKeyRequest;
import com.is.secureChatApp.service.KeyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/keys")
@RequiredArgsConstructor
public class KeyController {

    private final KeyService keyService;

    @PostMapping
    public ResponseEntity<PublicKeyResponse> registerPublicKey(
            @Valid @RequestBody RegisterPublicKeyRequest request
    ) {
        PublicKeyResponse response =
                keyService.registerPublicKey(request);

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(response);
    }

    @GetMapping("/{username}")
    public ResponseEntity<PublicKeyResponse> getPublicKey(
            @PathVariable String username
    ) {
        return ResponseEntity.ok(
                keyService.getPublicKey(username)
        );
    }
}
