
"""Secure message packet: build (sender side) and open (receiver side).

Wire packet fields:
    messageId, senderUsername, recipientUsername, sessionId,
    timestamp, nonce, ciphertext, hmac, signature

The timestamp is an ISO-8601 UTC string.
The server relays this packet but does not decrypt it.
"""

import base64
import json
from datetime import datetime, timezone

from .aes_module import aes_encrypt, aes_decrypt
from .hmac_module import derive_keys, compute_hmac, verify_hmac
from .signature_module import sign, verify_signature
from .secure_random import generate_nonce, generate_message_id
from .replay_guard import ReplayGuard, ACCEPTED


def b64e(data: bytes) -> str:
    return base64.b64encode(data).decode("ascii")


def b64d(value: str) -> bytes:
    return base64.b64decode(value, validate=True)


class PacketError(Exception):
    """Raised when a packet is rejected."""


def _parse_timestamp(value) -> datetime:
    """Parse an ISO-8601 timestamp and require a timezone."""
    if not isinstance(value, str):
        raise PacketError("MALFORMED TIMESTAMP")

    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise PacketError("MALFORMED TIMESTAMP") from exc

    if parsed.tzinfo is None:
        raise PacketError("MALFORMED TIMESTAMP")

    return parsed.astimezone(timezone.utc)


def _timestamp_seconds(value) -> float:
    return _parse_timestamp(value).timestamp()


def _hmac_input(packet: dict) -> bytes:
    """Canonical bytes covered by the HMAC (metadata + ciphertext)."""
    fields = [
        packet["messageId"],
        packet["senderUsername"],
        packet["recipientUsername"],
        packet["sessionId"],
        packet["timestamp"],
        packet["nonce"],
        packet["ciphertext"],
    ]
    return "|".join(fields).encode("utf-8")


def _signature_input(packet: dict) -> bytes:
    """Canonical bytes covered by the signature (everything except signature)."""
    return _hmac_input(packet) + b"|" + packet["hmac"].encode("ascii")


def create_packet(
    plaintext: str,
    session_key: bytes,
    sender_private_key_pem: bytes,
    sender_id: str,
    receiver_id: str,
    session_id: str,
) -> dict:
    """Encrypt, authenticate and sign a message packet."""
    if not all(
        isinstance(value, str) and value
        for value in (sender_id, receiver_id, session_id)
    ):
        raise PacketError("INVALID PACKET METADATA")

    enc_key, mac_key = derive_keys(session_key)

    timestamp = (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )

    packet = {
        "messageId": generate_message_id(),
        "senderUsername": sender_id,
        "recipientUsername": receiver_id,
        "sessionId": session_id,
        "timestamp": timestamp,
        "nonce": b64e(generate_nonce()),
        "ciphertext": b64e(aes_encrypt(enc_key, plaintext.encode("utf-8"))),
    }

    packet["hmac"] = b64e(compute_hmac(mac_key, _hmac_input(packet)))
    packet["signature"] = b64e(
        sign(sender_private_key_pem, _signature_input(packet))
    )

    return packet


def open_packet(
    packet: dict,
    session_key: bytes,
    sender_public_key_pem: bytes,
    replay_guard: ReplayGuard,
) -> str:
    """Verify and decrypt. Raises PacketError if the packet is rejected."""
    required = [
        "messageId",
        "senderUsername",
        "recipientUsername",
        "sessionId",
        "timestamp",
        "nonce",
        "ciphertext",
        "hmac",
        "signature",
    ]

    if not isinstance(packet, dict):
        raise PacketError("MALFORMED PACKET")

    if any(
        key not in packet
        or not isinstance(packet[key], str)
        or not packet[key]
        for key in required
    ):
        raise PacketError("MALFORMED PACKET")

    try:
        timestamp_seconds = _timestamp_seconds(packet["timestamp"])
        nonce_bytes = b64d(packet["nonce"])
        ciphertext_bytes = b64d(packet["ciphertext"])
        supplied_hmac = b64d(packet["hmac"])
        supplied_signature = b64d(packet["signature"])
    except (ValueError, TypeError, KeyError, PacketError) as exc:
        raise PacketError("MALFORMED PACKET") from exc

    # Reject stale/future packets before expensive cryptographic checks.
    now = datetime.now(timezone.utc).timestamp()
    if abs(now - timestamp_seconds) > replay_guard.window:
        raise PacketError("TIMESTAMP OUT OF WINDOW")

    enc_key, mac_key = derive_keys(session_key)

    # Authenticate before reserving replay identifiers.
    if not verify_hmac(mac_key, _hmac_input(packet), supplied_hmac):
        raise PacketError("HMAC VERIFICATION FAILED")

    if not verify_signature(
        sender_public_key_pem,
        _signature_input(packet),
        supplied_signature,
    ):
        raise PacketError("SIGNATURE VERIFICATION FAILED")

    # The guard records identifiers only after authentication succeeds.
    status = replay_guard.check(
        packet["messageId"],
        packet["nonce"],
        timestamp_seconds,
    )
    if status != ACCEPTED:
        raise PacketError(status)

    try:
        plaintext_bytes = aes_decrypt(enc_key, ciphertext_bytes)
        return plaintext_bytes.decode("utf-8")
    except (ValueError, UnicodeDecodeError) as exc:
        raise PacketError("DECRYPTION FAILED") from exc


def packet_to_json(packet: dict) -> str:
    return json.dumps(packet)


def packet_from_json(value: str) -> dict:
    return json.loads(value)
