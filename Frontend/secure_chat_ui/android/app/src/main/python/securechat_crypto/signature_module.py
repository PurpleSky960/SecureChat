"""SHA-256 hashing and RSA-PSS digital signatures (sender authenticity)."""
from Crypto.PublicKey import RSA
from Crypto.Signature import pss
from Crypto.Hash import SHA256


def sha256(data: bytes) -> bytes:
    return SHA256.new(data).digest()


def sign(private_key_pem: bytes, message: bytes) -> bytes:
    """Message -> SHA-256 -> RSA-PSS signature."""
    key = RSA.import_key(private_key_pem)
    return pss.new(key).sign(SHA256.new(message))


def verify_signature(public_key_pem: bytes, message: bytes, signature: bytes) -> bool:
    """Returns True if the signature is valid for message, else False."""
    key = RSA.import_key(public_key_pem)
    try:
        pss.new(key).verify(SHA256.new(message), signature)
        return True
    except (ValueError, TypeError):
        return False
