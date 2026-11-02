package com.is.secureChatApp.repository;

import com.is.secureChatApp.entity.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MessageRepository
        extends JpaRepository<Message, String> {

    List<Message> findBySession_SessionIdOrderByTimestampAsc(
            String sessionId
    );

    List<Message> findBySender_UserIdOrderByTimestampDesc(
            Long senderId
    );

    List<Message> findByReceiver_UserIdOrderByTimestampDesc(
            Long receiverId
    );

    Optional<Message> findByNonce(String nonce);

    boolean existsByMessageId(String messageId);

    boolean existsByNonce(String nonce);
}