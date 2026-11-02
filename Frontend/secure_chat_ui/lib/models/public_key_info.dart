class PublicKeyInfo {
  const PublicKeyInfo({
    required this.username,
    required this.publicKey,
    required this.algorithm,
    required this.fingerprint,
    required this.status,
    this.createdAt,
  });

  final String username;
  final String publicKey;
  final String algorithm;
  final String fingerprint;
  final String status;
  final DateTime? createdAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory PublicKeyInfo.fromJson(Map<String, dynamic> json) {
    return PublicKeyInfo(
      username: json['username'] as String,
      publicKey: json['publicKey'] as String,
      algorithm: json['algorithm'] as String,
      fingerprint: json['fingerprint'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
