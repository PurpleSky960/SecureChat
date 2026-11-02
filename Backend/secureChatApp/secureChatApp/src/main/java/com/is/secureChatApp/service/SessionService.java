package com.is.secureChatApp.service;

import com.is.secureChatApp.dto.CreateSessionRequest;
import com.is.secureChatApp.dto.SessionResponse;
import com.is.secureChatApp.entity.Session;
import com.is.secureChatApp.entity.User;
import com.is.secureChatApp.repository.SessionRepository;
import com.is.secureChatApp.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class SessionService {

    private final UserRepository userRepository;
    private final SessionRepository sessionRepository;

    @Transactional
    public SessionResponse createSession(
            String authenticatedUsername,
            CreateSessionRequest request
    ) {
        String username = normalize(authenticatedUsername);
        String peerUsername = normalize(request.peerUsername());

        if (username.equals(peerUsername)) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST,
                    "Cannot create a session with yourself"
            );
        }

        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Authenticated user account does not exist"
                ));

        User peer = userRepository.findByUsername(peerUsername)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Peer account does not exist"
                ));

        if (!"ACTIVE".equals(user.getStatus())
                || !"ACTIVE".equals(peer.getStatus())) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "Both accounts must be active"
            );
        }

        Session session = new Session();
        session.setSessionId(UUID.randomUUID().toString());
        session.setUser(user);
        session.setPeer(peer);
        session.setStatus("ACTIVE");

        Session saved = sessionRepository.save(session);

        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<SessionResponse> getMySessions(
            String authenticatedUsername
    ) {
        User user = findUser(authenticatedUsername);

        List<Session> sessions =
                sessionRepository
                        .findByUser_UserIdOrPeer_UserIdOrderByCreatedAtDesc(
                                user.getUserId(),
                                user.getUserId()
                        );

        return sessions.stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public SessionResponse getSession(
            String authenticatedUsername,
            String sessionId
    ) {
        User user = findUser(authenticatedUsername);
        Session session = findSession(sessionId);

        verifyParticipant(user, session);
        updateExpiry(session);

        return toResponse(session);
    }

    @Transactional
    public void terminateSession(
            String authenticatedUsername,
            String sessionId
    ) {
        User user = findUser(authenticatedUsername);
        Session session = findSession(sessionId);

        verifyParticipant(user, session);

        if ("TERMINATED".equals(session.getStatus())) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Session is already terminated"
            );
        }

        updateExpiry(session);

        session.setStatus("TERMINATED");
        sessionRepository.save(session);
    }

    private User findUser(String username) {
        return userRepository.findByUsername(normalize(username))
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "User account does not exist"
                ));
    }

    private Session findSession(String sessionId) {
        return sessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Session does not exist"
                ));
    }

    private void verifyParticipant(User user, Session session) {
        Long userId = user.getUserId();

        boolean isParticipant =
                session.getUser().getUserId().equals(userId)
                        || session.getPeer().getUserId().equals(userId);

        if (!isParticipant) {
            throw new ResponseStatusException(
                    HttpStatus.FORBIDDEN,
                    "You are not a participant in this session"
            );
        }
    }

    private void updateExpiry(Session session) {
        if ("ACTIVE".equals(session.getStatus())
                && session.getExpiresAt() != null
                && session.getExpiresAt().isBefore(Instant.now())) {

            session.setStatus("EXPIRED");
            sessionRepository.save(session);
        }
    }

    private SessionResponse toResponse(Session session) {
        return new SessionResponse(
                session.getSessionId(),
                session.getUser().getUsername(),
                session.getPeer().getUsername(),
                session.getCreatedAt(),
                session.getExpiresAt(),
                session.getStatus()
        );
    }

    private String normalize(String username) {
        return username.trim().toLowerCase(Locale.ROOT);
    }
}