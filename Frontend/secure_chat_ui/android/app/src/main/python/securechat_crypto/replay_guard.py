"""Replay protection: message ID + timestamp window + nonce tracking."""
import time
import threading

ACCEPTED = "ACCEPTED"
REPLAY = "REPLAY DETECTED"
EXPIRED = "TIMESTAMP OUT OF WINDOW"


class ReplayGuard:
    """In-memory replay detector.

    A packet is rejected if its messageId or nonce was seen before, or if its
    timestamp is outside +/- window_seconds of the current time. Seen entries
    are kept only as long as they could still pass the timestamp check.
    """

    def __init__(self, window_seconds: int = 300):
        self.window = window_seconds
        self._seen_ids = {}     # messageId -> timestamp
        self._seen_nonces = {}  # nonce -> timestamp
        self._lock = threading.Lock()

    def check(self, message_id: str, nonce: str, timestamp: int, now: float = None) -> str:
        now = time.time() if now is None else now
        with self._lock:
            self._purge(now)
            if abs(now - timestamp) > self.window:
                return EXPIRED
            if message_id in self._seen_ids or nonce in self._seen_nonces:
                return REPLAY
            self._seen_ids[message_id] = timestamp
            self._seen_nonces[nonce] = timestamp
            return ACCEPTED

    def _purge(self, now: float):
        for store in (self._seen_ids, self._seen_nonces):
            for k in [k for k, ts in store.items() if now - ts > self.window]:
                del store[k]
