import 'dart:convert';

/// QUÉ HACE:
/// Modela el perfil persistente de cuenta almacenado en Firestore/Local.
///
/// CÓMO FUNCIONA:
/// Contiene el plan actual, configuración mínima sincronizable y timestamps de auditoría.
/// No almacena ningún secreto, contraseña ni contenido privado local de Nano.
///
/// POR QUÉ:
/// Garantiza la política de Privacidad y Local-First: Firebase solo almacena identidad,
/// estado de cuenta y plan. Las conversaciones, memoria y automatizaciones quedan en el dispositivo.
class AccountProfile {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String phone;
  final String country;
  final String? photoUrl;
  final String status; // active, suspended, disabled
  final String planTier; // free, pro, business
  final String entitlementSource; // play_billing, promo, none
  final bool syncEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const AccountProfile({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.country = '',
    this.photoUrl,
    this.status = 'active',
    this.planTier = 'free',
    this.entitlementSource = 'none',
    this.syncEnabled = false,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  /// Perfil vacío para usuarios anónimos o no inicializados.
  static const AccountProfile empty = AccountProfile(
    uid: '',
    email: '',
    displayName: '',
    firstName: '',
    lastName: '',
    phone: '',
    country: '',
    photoUrl: null,
    status: 'inactive',
    planTier: 'free',
    entitlementSource: 'none',
    syncEnabled: false,
  );

  bool get isPro => planTier.toLowerCase() == 'pro' || isBusiness;
  bool get isBusiness => planTier.toLowerCase() == 'business';
  bool get isActive => status.toLowerCase() == 'active';

  AccountProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? photoUrl,
    String? status,
    String? planTier,
    String? entitlementSource,
    bool? syncEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AccountProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      planTier: planTier ?? this.planTier,
      entitlementSource: entitlementSource ?? this.entitlementSource,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'country': country,
      'photoUrl': photoUrl,
      'status': status,
      'planTier': planTier,
      'entitlementSource': entitlementSource,
      'syncEnabled': syncEnabled,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory AccountProfile.fromMap(Map<String, dynamic> map) {
    final first = map['firstName'] as String? ?? '';
    final last = map['lastName'] as String? ?? '';
    var display = map['displayName'] as String? ?? '';
    if (display.isEmpty && (first.isNotEmpty || last.isNotEmpty)) {
      display = '$first $last'.trim();
    }
    return AccountProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: display,
      firstName: first,
      lastName: last,
      phone: map['phone'] as String? ?? '',
      country: map['country'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'active',
      planTier: map['planTier'] as String? ?? 'free',
      entitlementSource: map['entitlementSource'] as String? ?? 'none',
      syncEnabled: map['syncEnabled'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.tryParse(map['lastLoginAt'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AccountProfile.fromJson(String source) =>
      AccountProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
