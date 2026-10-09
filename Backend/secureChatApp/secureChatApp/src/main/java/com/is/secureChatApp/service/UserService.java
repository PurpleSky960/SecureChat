
package com.is.secureChatApp.service;

import com.is.secureChatApp.entity.User;
import com.is.secureChatApp.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PasswordService passwordService;

    private String normalizeUsername(String username) {
        return username.trim().toLowerCase(Locale.ROOT);
    }

    public Optional<User> findByUsername(String username) {
        return userRepository.findByUsername(
                normalizeUsername(username)
        );
    }

    public boolean usernameExists(String username) {
        return userRepository.existsByUsername(
                normalizeUsername(username)
        );
    }

    @Transactional
    public User createUser(String username, String password) {
        String normalizedUsername = normalizeUsername(username);

        if (userRepository.existsByUsername(normalizedUsername)) {
            throw new IllegalArgumentException(
                    "Username is already taken"
            );
        }

        String salt = passwordService.generateSalt();
        String hash = passwordService.hashPassword(password, salt);

        User user = new User();
        user.setUsername(normalizedUsername);
        user.setPasswordHash(hash);
        user.setPasswordSalt(salt);
        user.setStatus("ACTIVE");

        return userRepository.save(user);
    }
}
