"""HMAC-SHA256 (message integrity) and key derivation.

One session key is split into two independent keys via HKDF so the same key
is never used for both encryption and authentication.
"""
from Crypto.Hash import HMAC, SHA256
from Crypto.Protocol.KDF import HKDF


def derive_keys(session_key: bytes):
    """Returns (enc_key, mac_key), each 32 bytes, derived from the session key."""
    material = HKDF(session_key, 64, salt=b"securechat-v1", hashmod=SHA256)
    return material[:32], material[32:]


def compute_hmac(mac_key: bytes, data: bytes) -> bytes:
    """HMAC-SHA256 tag over data."""
    return HMAC.new(mac_key, data, SHA256).digest()


def verify_hmac(mac_key: bytes, data: bytes, tag: bytes) -> bool:
    """Constant-time HMAC verification. Returns True/False."""
    try:
        HMAC.new(mac_key, data, SHA256).verify(tag)
        return True
    except ValueError:
        return False
