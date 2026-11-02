"""RSA key generation and RSA-OAEP key protection (secure key establishment)."""
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP
from Crypto.Hash import SHA256

RSA_KEY_BITS = 2048


def generate_rsa_keypair(bits: int = RSA_KEY_BITS):
    """Returns (private_key_pem, public_key_pem) as bytes.

    The public key PEM is what gets registered with the Spring Boot server.
    The private key must NEVER leave the client / be stored in PostgreSQL.
    """
    key = RSA.generate(bits)
    return key.export_key(), key.publickey().export_key()


def rsa_oaep_encrypt(public_key_pem: bytes, data: bytes) -> bytes:
    """Encrypt a small value (e.g. AES session key) with RSA-OAEP (SHA-256)."""
    cipher = PKCS1_OAEP.new(RSA.import_key(public_key_pem), hashAlgo=SHA256)
    return cipher.encrypt(data)


def rsa_oaep_decrypt(private_key_pem: bytes, encrypted: bytes) -> bytes:
    """Decrypt an RSA-OAEP protected value. Raises ValueError on failure."""
    cipher = PKCS1_OAEP.new(RSA.import_key(private_key_pem), hashAlgo=SHA256)
    return cipher.decrypt(encrypted)
