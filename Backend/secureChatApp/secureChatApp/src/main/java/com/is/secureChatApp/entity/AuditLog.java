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
        name = "audit_logs",
        indexes = {
                @Index(name = "idx_audit_logs_user", columnList = "user_id"),
                @Index(name = "idx_audit_logs_timestamp", columnList = "timestamp")
        }
)
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "log_id")
    private Long logId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "event_type", nullable = false, length = 100)
    private String eventType;

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;

    @Column(name = "details", columnDefinition = "TEXT")
    private String details;

    @PrePersist
    protected void onCreate() {
        if (timestamp == null) {
            timestamp = Instant.now();
        }
    }
}