
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
    private final JwtService jwtService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {

        User user = userService.createUser(
                request.username(),
                request.password()
        );

        String token = jwtService.generateToken(
                user.getUserId(),
                user.getUsername()
        );

        return new AuthResponse(
                "Registration successful",
                user.getUserId(),
                user.getUsername(),
                token,
                "Bearer"
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

        if (!passwordMatches || !"ACTIVE".equals(user.getStatus())) {
            throw new IllegalArgumentException(
                    "Invalid username or password"
            );
        }

        user.setLastLogin(java.time.Instant.now());

        String token = jwtService.generateToken(
                user.getUserId(),
                user.getUsername()
        );

        return new AuthResponse(
                "Login successful",
                user.getUserId(),
                user.getUsername(),
                token,
                "Bearer"
        );
    }
}
