
package com.is.secureChatApp.repository;

import com.is.secureChatApp.entity.PublicKey;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PublicKeyRepository
        extends JpaRepository<PublicKey, Long> {

    Optional<PublicKey> findByUser_UserId(Long userId);

    Optional<PublicKey> findByUser_UsernameAndStatus(
            String username,
            String status
    );
}
