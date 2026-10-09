
package com.is.secureChatApp.service;

import com.is.secureChatApp.dto.AuthResponse;
import com.is.secureChatApp.dto.LoginRequest;
import com.is.secureChatApp.dto.RegisterRequest;
import com.is.secureChatApp.entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserService userService;
    private final PasswordService passwordService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        User user = userService.createUser(
                request.username(),
                request.password()
        );

        /*
         * TODO (Python security integration):
         * Later, the Flutter client will invoke the Python
         * security layer to generate an RSA key pair.
         *
         * The private key must remain on the client.
         * The public key will be uploaded to Spring Boot
         * through a separate public-key registration endpoint.
         * Do not call a Python function here yet.
         */

        return new AuthResponse(
                "Registration successful",
                user.getUserId(),
                user.getUsername()
        );
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = userService.findByUsername(request.username())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Invalid username or password"
                ));

        boolean passwordMatches =
                passwordService.verifyPassword(
                        request.password(),
                        user.getPasswordHash(),
                        user.getPasswordSalt()
                );

        if (!passwordMatches ||
                !"ACTIVE".equals(user.getStatus())) {
            throw new IllegalArgumentException(
                    "Invalid username or password"
            );
        }

        user.setLastLogin(java.time.Instant.now());

        /*
         * TODO (Python security integration):
         * After authentication, the client may initialize
         * its Python crypto layer and access its locally
         * stored private key.
         *
         * Do not send the private key or plaintext chat
         * messages to this backend.
         */

        return new AuthResponse(
                "Login successful",
                user.getUserId(),
                user.getUsername()
        );
    }
}
