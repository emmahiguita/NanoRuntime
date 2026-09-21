import 'dart:convert';

/// Modelo de datos que representa una credencial de acceso guardada para un sitio web.
class BrowserCredential {
  final String id;
  final String domain;
  final String username;
  final String password;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const BrowserCredential({
    required this.id,
    required this.domain,
    required this.username,
    required this.password,
    required this.createdAt,
    required this.lastUsedAt,
  });

  BrowserCredential copyWith({
    String? id,
    String? domain,
    String? username,
    String? password,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return BrowserCredential(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domain': domain,
      'username': username,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt.toIso8601String(),
    };
  }

  factory BrowserCredential.fromMap(Map<String, dynamic> map) {
    return BrowserCredential(
      id: map['id'] as String? ?? '',
      domain: map['domain'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.tryParse(map['lastUsedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BrowserCredential.fromJson(String source) =>
      BrowserCredential.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrowserCredential &&
        other.id == id &&
        other.domain == domain &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode =>
      id.hashCode ^ domain.hashCode ^ username.hashCode ^ password.hashCode;
}
