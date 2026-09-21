import 'dart:convert';

/// QUÉ HACE:
/// Representa a un usuario autenticado dentro del ecosistema Nano Mobile.
///
/// CÓMO FUNCIONA:
/// Modela los atributos elementales de identidad provistos por el proveedor
/// de autenticación (Firebase UID, email, nombre y estado de verificación).
/// Es una entidad inmutable pura sin dependencias de infraestructura ni frameworks.
///
/// POR QUÉ:
/// Cumple con Clean Architecture (Domain Layer): aísla la lógica de negocio
/// de las clases de Firebase Auth (`User`), permitiendo pruebas unitarias limpias
/// y portabilidad a otros mecanismos de identidad si fuera necesario.
class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final bool isAnonymous;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl,
    this.isEmailVerified = false,
    this.isAnonymous = false,
  });

  /// Usuario vacío para estados no autenticados o nulos.
  static const AuthUser empty = AuthUser(
    uid: '',
    email: '',
    displayName: '',
    photoUrl: null,
    isEmailVerified: false,
    isAnonymous: false,
  );

  bool get isEmpty => uid.isEmpty;
  bool get isNotEmpty => uid.isNotEmpty;

  /// Obtiene iniciales para avatares en la interfaz de usuario.
  String get initials {
    if (displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final p1 = parts[0].isNotEmpty ? parts[0][0] : '';
        final p2 = parts[1].isNotEmpty ? parts[1][0] : '';
        return (p1 + p2).toUpperCase();
      }
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return email.isNotEmpty ? email.substring(0, 1).toUpperCase() : '?';
  }

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    bool? isAnonymous,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'isAnonymous': isAnonymous,
    };
  }

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      isAnonymous: map['isAnonymous'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AuthUser.fromJson(String source) =>
      AuthUser.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthUser &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.isEmailVerified == isEmailVerified &&
        other.isAnonymous == isAnonymous;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      email,
      displayName,
      photoUrl,
      isEmailVerified,
      isAnonymous,
    );
  }
}
