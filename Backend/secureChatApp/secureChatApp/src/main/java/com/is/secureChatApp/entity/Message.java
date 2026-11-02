package com.is.secureChatApp.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Getter
@Setter
@NoArgsConstructor
@Table(
        name = "messages",
        indexes = {
                @Index(name = "idx_messages_sender", columnList = "sender_id"),
                @Index(name = "idx_messages_receiver", columnList = "receiver_id"),
                @Index(name = "idx_messages_session", columnList = "session_id"),
                @Index(name = "idx_messages_timestamp", columnList = "timestamp")
        }
)
public class Message {

    @Id
    @Column(name = "message_id", length = 100)
    private String messageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "session_id", nullable = false)
    private Session session;

    @Column(name = "ciphertext", nullable = false,
            columnDefinition = "TEXT")
    private String ciphertext;

    @Column(name = "nonce", nullable = false,
            unique = true, columnDefinition = "TEXT")
    private String nonce;

    @Column(name = "hmac", nullable = false,
            columnDefinition = "TEXT")
    private String hmac;

    @Column(name = "signature", nullable = false,
            columnDefinition = "TEXT")
    private String signature;

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;

    @Column(nullable = false, length = 20)
    private String status = "SENT";

    @PrePersist
    protected void onCreate() {
        if (timestamp == null) {
            timestamp = Instant.now();
        }

        if (status == null) {
            status = "SENT";
        }
    }
}