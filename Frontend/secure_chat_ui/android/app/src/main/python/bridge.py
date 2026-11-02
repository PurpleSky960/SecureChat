
import base64
import json
import traceback

from securechat_crypto.aes_module import aes_encrypt, aes_decrypt
from securechat_crypto.hmac_module import derive_keys
from securechat_crypto.packet import create_packet, open_packet, PacketError
from securechat_crypto.replay_guard import ReplayGuard
from securechat_crypto.rsa_module import (
    generate_rsa_keypair,
    rsa_oaep_encrypt,
    rsa_oaep_decrypt,
)
from securechat_crypto.secure_random import generate_session_key


def _b64e(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def _b64d(value: str) -> bytes:
    return base64.b64decode(value, validate=True)


class SecureChatBridge:
    def __init__(self):
        self.replay_guard = ReplayGuard()

    def handle(self, operation: str, payload_json: str) -> str:
        try:
            payload = json.loads(payload_json or "{}")

            if operation == "aes_roundtrip":
                key = generate_session_key()
                plaintext = payload.get("text", "Chaquopy works!")
                enc_key, _ = derive_keys(key)
                encrypted = aes_encrypt(enc_key, plaintext.encode("utf-8"))
                decrypted = aes_decrypt(enc_key, encrypted)
                return json.dumps({
                    "ok": True,
                    "plaintext": decrypted.decode("utf-8"),
                    "ciphertext": _b64e(encrypted),
                })

            if operation == "generate_keypair":
                private_pem, public_pem = generate_rsa_keypair()
                return json.dumps({
                    "ok": True,
                    "privateKey": _b64e(private_pem),
                    "publicKey": _b64e(public_pem),
                })

            if operation == "generate_session_key":
                return json.dumps({
                    "ok": True,
                    "sessionKey": _b64e(generate_session_key()),
                })

            if operation == "encrypt_session_key":
                encrypted = rsa_oaep_encrypt(
                    _b64d(payload["publicKey"].encode("ascii")),
                    _b64d(payload["sessionKey"].encode("ascii")),
                )
                return json.dumps({"ok": True, "encryptedSessionKey": _b64e(encrypted)})

            if operation == "decrypt_session_key":
                session_key = rsa_oaep_decrypt(
                    _b64d(payload["privateKey"].encode("ascii")),
                    _b64d(payload["encryptedSessionKey"].encode("ascii")),
                )
                return json.dumps({"ok": True, "sessionKey": _b64e(session_key)})

            if operation == "create_packet":
                packet = create_packet(
                    plaintext=payload["plaintext"],
                    session_key=_b64d(payload["sessionKey"]),
                    sender_private_key_pem=_b64d(payload["privateKey"]),
                    sender_id=payload["senderUsername"],
                    receiver_id=payload["recipientUsername"],
                    session_id=payload["sessionId"],
                )
                return json.dumps({"ok": True, "packet": packet})

            if operation == "open_packet":
                plaintext = open_packet(
                    packet=payload["packet"],
                    session_key=_b64d(payload["sessionKey"]),
                    sender_public_key_pem=_b64d(payload["publicKey"]),
                    replay_guard=self.replay_guard,
                )
                return json.dumps({"ok": True, "plaintext": plaintext})

            return json.dumps({"ok": False, "error": "UNKNOWN_OPERATION"})

        except Exception as exc:
            # Return a controlled error; never return plaintext or key material here.
            message = str(exc) if isinstance(exc, PacketError) else "CRYPTO_OPERATION_FAILED"
            return json.dumps({"ok": False, "error": message})


bridge = SecureChatBridge()


def handle(operation: str, payload_json: str = "{}") -> str:
    return bridge.handle(operation, payload_json)
