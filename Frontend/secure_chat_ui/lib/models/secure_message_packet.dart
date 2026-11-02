class SecureMessagePacket {
  const SecureMessagePacket({
    required this.messageId,
    required this.senderUsername,
    required this.recipientUsername,
    required this.sessionId,
    required this.timestamp,
    required this.nonce,
    required this.ciphertext,
    required this.hmac,
    required this.signature,
  });

  final String messageId;
  final String senderUsername;
  final String recipientUsername;
  final String sessionId;
  final String timestamp;
  final String nonce;
  final String ciphertext;
  final String hmac;
  final String signature;

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'senderUsername': senderUsername,
    'recipientUsername': recipientUsername,
    'sessionId': sessionId,
    'timestamp': timestamp,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'hmac': hmac,
    'signature': signature,
  };

  factory SecureMessagePacket.fromJson(Map<String, dynamic> json) {
    return SecureMessagePacket(
      messageId: json['messageId'] as String,
      senderUsername: json['senderUsername'] as String,
      recipientUsername: json['recipientUsername'] as String,
      sessionId: json['sessionId'] as String,
      timestamp: json['timestamp'] as String,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      hmac: json['hmac'] as String,
      signature: json['signature'] as String,
    );
  }
}
