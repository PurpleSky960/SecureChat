"""Secure random value generation (AES session key, nonce, salt, message ID)."""
import uuid
from Crypto.Random import get_random_bytes

AES_KEY_SIZE = 32   # 256-bit session key
NONCE_SIZE = 16
SALT_SIZE = 16


def generate_session_key() -> bytes:
    """Random 256-bit AES session key."""
    return get_random_bytes(AES_KEY_SIZE)


def generate_nonce() -> bytes:
    """Random nonce used for replay protection."""
    return get_random_bytes(NONCE_SIZE)


def generate_salt() -> bytes:
    """Random salt (e.g. for password hashing)."""
    return get_random_bytes(SALT_SIZE)


def generate_message_id() -> str:
    """Unique message ID (random UUID4)."""
    return str(uuid.uuid4())
