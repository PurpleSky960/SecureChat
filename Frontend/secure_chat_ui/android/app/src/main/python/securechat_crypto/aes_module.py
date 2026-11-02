"""AES-256-CBC encryption/decryption (confidentiality).

Integrity is provided separately by HMAC-SHA256 (encrypt-then-MAC), see
hmac_module.py. A fresh random IV is generated per message and prepended
to the ciphertext (iv || ciphertext), so the packet format needs no extra field.
"""
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from Crypto.Random import get_random_bytes

IV_SIZE = AES.block_size  # 16


def aes_encrypt(key: bytes, plaintext: bytes) -> bytes:
    """Encrypt plaintext. Returns iv || ciphertext."""
    if len(key) not in (16, 24, 32):
        raise ValueError("AES key must be 16, 24 or 32 bytes")
    iv = get_random_bytes(IV_SIZE)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return iv + cipher.encrypt(pad(plaintext, AES.block_size))


def aes_decrypt(key: bytes, data: bytes) -> bytes:
    """Decrypt iv || ciphertext. Raises ValueError on bad padding/length."""
    if len(data) < 2 * IV_SIZE or len(data) % AES.block_size != 0:
        raise ValueError("Invalid ciphertext length")
    iv, ct = data[:IV_SIZE], data[IV_SIZE:]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return unpad(cipher.decrypt(ct), AES.block_size)
