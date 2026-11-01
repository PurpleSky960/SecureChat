-- SecureChat PostgreSQL schema (matches the ERD, Fig. 3 of the report)
-- Run:  psql -U postgres -d securechat -f schema.sql
-- The database never stores plaintext messages, private RSA keys or plaintext AES keys.

DROP TABLE IF EXISTS audit_logs, messages, sessions, public_keys, users CASCADE;

CREATE TABLE users (
    user_id        BIGSERIAL PRIMARY KEY,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    password_salt  VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP  NOT NULL DEFAULT now(),
    last_login     TIMESTAMP,
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE public_keys (
    key_id      BIGSERIAL PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    public_key  TEXT        NOT NULL,                 -- PEM, public part only
    algorithm   VARCHAR(20) NOT NULL DEFAULT 'RSA-2048',
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE sessions (
    session_id  VARCHAR(36) PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES users(user_id),
    peer_id     BIGINT      NOT NULL REFERENCES users(user_id),
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    expires_at  TIMESTAMP NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE messages (
    message_id   VARCHAR(36) PRIMARY KEY,             -- packet messageId (UUID4 text); duplicate = replay
    sender_id    BIGINT      NOT NULL REFERENCES users(user_id),
    receiver_id  BIGINT      NOT NULL REFERENCES users(user_id),
    session_id   VARCHAR(36) NOT NULL REFERENCES sessions(session_id),
    ciphertext   TEXT        NOT NULL,                -- Base64, iv + AES ciphertext only
    nonce        VARCHAR(64) NOT NULL UNIQUE,         -- duplicate nonce = replay
    hmac         TEXT        NOT NULL,
    signature    TEXT        NOT NULL,
    "timestamp"  TIMESTAMP   NOT NULL,                -- packet time, e.g. to_timestamp(unix_seconds) AT TIME ZONE 'UTC'
    status       VARCHAR(20) NOT NULL DEFAULT 'RELAYED'
);

CREATE TABLE audit_logs (
    log_id      BIGSERIAL PRIMARY KEY,
    user_id     BIGINT REFERENCES users(user_id),
    event_type  VARCHAR(50) NOT NULL,                 -- e.g. LOGIN, REPLAY_DETECTED, HMAC_FAILED
    "timestamp" TIMESTAMP NOT NULL DEFAULT now(),
    details     TEXT
);

CREATE INDEX idx_public_keys_user ON public_keys(user_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_session ON messages(session_id);
