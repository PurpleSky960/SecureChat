
package com.is.secureChatApp.service;

import com.is.secureChatApp.dto.SecureMessagePacket;
import com.is.secureChatApp.entity.AuditLog;
import com.is.secureChatApp.entity.Message;
import com.is.secureChatApp.entity.Session;
import com.is.secureChatApp.entity.User;
import com.is.secureChatApp.repository.AuditLogRepository;
import com.is.secureChatApp.repository.MessageRepository;
import com.is.secureChatApp.repository.SessionRepository;
import com.is.secureChatApp.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class MessagePersistenceService {

    private final UserRepository userRepository;
    private final SessionRepository sessionRepository;
    private final MessageRepository messageRepository;
    private final AuditLogRepository auditLogRepository;

    @Transactional
    public void persist(SecureMessagePacket packet) {

        // Normalize usernames.
        String senderUsername =
                packet.senderUsername().trim().toLowerCase(Locale.ROOT);

        String recipientUsername =
                packet.recipientUsername().trim().toLowerCase(Locale.ROOT);

        // Reject duplicate message IDs.
        if (messageRepository.existsByMessageId(packet.messageId())) {
            throw new IllegalArgumentException(
                    "Duplicate message ID"
            );
        }

        // Reject reused cryptographic nonces.
        if (messageRepository.existsByNonce(packet.nonce())) {
            throw new IllegalArgumentException(
                    "Duplicate message nonce"
            );
        }

        // Resolve sender.
        User sender = userRepository.findByUsername(senderUsername)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Sender account does not exist"
                ));

        // Resolve recipient.
        User recipient = userRepository.findByUsername(recipientUsername)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Recipient account does not exist"
                ));

        // Both accounts must be active.
        if (!"ACTIVE".equals(sender.getStatus())
                || !"ACTIVE".equals(recipient.getStatus())) {

            throw new IllegalArgumentException(
                    "Both accounts must be active"
            );
        }

        // Resolve an active database session.
        Session session =
                sessionRepository.findBySessionIdAndStatus(
                        packet.sessionId(),
                        "ACTIVE"
                ).orElseThrow(() -> new IllegalArgumentException(
                        "Active session does not exist"
                ));

        Instant now = Instant.now();

        // Reject expired sessions.
        if (session.getExpiresAt() != null
                && !session.getExpiresAt().isAfter(now)) {

            throw new IllegalArgumentException(
                    "Session has expired"
            );
        }

        // Confirm that both users belong to this session.
        Long sessionUserId = session.getUser().getUserId();
        Long sessionPeerId = session.getPeer().getUserId();

        boolean validParticipants =
                (sessionUserId.equals(sender.getUserId())
                        && sessionPeerId.equals(recipient.getUserId()))
                        ||
                        (sessionUserId.equals(recipient.getUserId())
                                && sessionPeerId.equals(sender.getUserId()));

        if (!validParticipants) {
            throw new IllegalArgumentException(
                    "Sender and recipient do not belong to this session"
            );
        }

        // Create the message record.
        Message message = new Message();

        message.setMessageId(packet.messageId());
        message.setSender(sender);
        message.setReceiver(recipient);
        message.setSession(session);

        // Store encrypted data without decrypting it.
        message.setCiphertext(packet.ciphertext());
        message.setNonce(packet.nonce());
        message.setHmac(packet.hmac());
        message.setSignature(packet.signature());

        message.setTimestamp(packet.timestamp());
        message.setStatus("SENT");

        try {
            messageRepository.saveAndFlush(message);
        } catch (DataIntegrityViolationException exception) {
            throw new IllegalArgumentException(
                    "Message ID or nonce already exists"
            );
        }

        // Record a non-sensitive audit event.
        AuditLog auditLog = new AuditLog();

        auditLog.setUser(sender);
        auditLog.setEventType("MESSAGE_STORED");
        auditLog.setTimestamp(now);
        auditLog.setDetails(
                "Message ID: " + packet.messageId()
                        + "; recipient: " + recipientUsername
        );

        auditLogRepository.save(auditLog);
    }
}
