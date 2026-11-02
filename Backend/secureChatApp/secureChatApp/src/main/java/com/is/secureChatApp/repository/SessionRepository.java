package com.is.secureChatApp.repository;

import com.is.secureChatApp.entity.Session;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SessionRepository
        extends JpaRepository<Session, String> {

    List<Session> findByUser_UserIdOrPeer_UserIdOrderByCreatedAtDesc(
            Long userId,
            Long peerId
    );

    Optional<Session> findBySessionIdAndStatus(
            String sessionId,
            String status
    );
}