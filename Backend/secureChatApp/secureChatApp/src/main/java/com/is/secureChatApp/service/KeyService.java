
package com.is.secureChatApp.service;

import com.is.secureChatApp.dto.PublicKeyResponse;
import com.is.secureChatApp.dto.RegisterPublicKeyRequest;
import com.is.secureChatApp.entity.PublicKey;
import com.is.secureChatApp.entity.User;
import com.is.secureChatApp.repository.PublicKeyRepository;
import com.is.secureChatApp.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HexFormat;

@Service
@RequiredArgsConstructor
public class KeyService {

    private final PublicKeyRepository publicKeyRepository;
    private final UserRepository userRepository;

    @Transactional
    public PublicKeyResponse registerPublicKey(
            RegisterPublicKeyRequest request
    ) {
        String username = request.username()
                .trim()
                .toLowerCase(java.util.Locale.ROOT);

        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException(
                        "User does not exist"
                ));

        // TODO (Python security integration):
        // The client-side Python crypto layer will generate
        // the RSA key pair. The private key must stay client-side.
        // The client sends only the public key to this endpoint.
        //
        // TODO (Authentication integration):
        // Replace the request-supplied username with the
        // authenticated user's identity before production use.

        byte[] encodedKey;

        try {
            encodedKey = Base64.getDecoder()
                    .decode(request.publicKey());

            KeyFactory keyFactory = KeyFactory.getInstance("RSA");

            java.security.PublicKey parsedKey = keyFactory.generatePublic(
                    new X509EncodedKeySpec(encodedKey)
            );

            if (!(parsedKey instanceof java.security.interfaces.RSAPublicKey rsaKey)) {
                throw new IllegalArgumentException(
                        "An RSA public key is required"
                );
            }

            if (rsaKey.getModulus().bitLength() < 2048) {
                throw new IllegalArgumentException(
                        "RSA key must be at least 2048 bits"
                );
            }

        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(
                    "Invalid RSA public key encoding"
            );
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalArgumentException(
                    "Invalid RSA public key"
            );
        }

        String fingerprint;

        try {
            byte[] digest = MessageDigest
                    .getInstance("SHA-256")
                    .digest(encodedKey);

            fingerprint = HexFormat.of().formatHex(digest);

        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(
                    "SHA-256 is unavailable", e
            );
        }

        PublicKey key = publicKeyRepository
                .findByUser_UserId(user.getUserId())
                .orElseGet(PublicKey::new);

        key.setUser(user);
        key.setPublicKey(
                Base64.getEncoder().encodeToString(encodedKey)
        );
        key.setAlgorithm("RSA");
        key.setFingerprint(fingerprint);
        key.setStatus("ACTIVE");

        PublicKey savedKey = publicKeyRepository.save(key);

        return toResponse(savedKey);
    }

    @Transactional(readOnly = true)
    public PublicKeyResponse getPublicKey(String username) {
        String normalizedUsername = username
                .trim()
                .toLowerCase(java.util.Locale.ROOT);

        PublicKey key = publicKeyRepository
                .findByUser_UsernameAndStatus(
                        normalizedUsername,
                        "ACTIVE"
                )
                .orElseThrow(() -> new IllegalArgumentException(
                        "No active public key found for this user"
                ));

        // TODO (Python security integration):
        // The recipient's client will consume this public key.
        // The Python crypto layer will use it for RSA-OAEP
        // session-key protection and signature verification
        // workflows as appropriate.

        return toResponse(key);
    }

    private PublicKeyResponse toResponse(PublicKey key) {
        return new PublicKeyResponse(
                key.getUser().getUsername(),
                key.getPublicKey(),
                key.getAlgorithm(),
                key.getFingerprint(),
                key.getCreatedAt(),
                key.getStatus()
        );
    }
}
