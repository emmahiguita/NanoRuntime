import 'dart:convert';

/// QUÉ HACE: Modela el perfil de usuario (datos personales, ubicación y contacto).
/// CÓMO FUNCIONA: Identidad soberana local-first y sincronizable sin secretos ni datos de agentes.
/// POR QUÉ: Principio de Privacidad Soberana: separa la identidad de métricas del sistema.
class AccountProfile {
  final String uid, email, displayName, firstName, lastName, username;
  final String phone, country, stateProvince, city, address, gender, bio, language;
  final String? photoUrl;
  final String status, planTier, entitlementSource;
  final bool syncEnabled;
  final DateTime? birthDate, createdAt, updatedAt, lastLoginAt;

  const AccountProfile({
    required this.uid, required this.email,
    this.displayName = '', this.firstName = '', this.lastName = '',
    this.username = '', this.phone = '', this.country = '',
    this.stateProvince = '', this.city = '', this.address = '',
    this.gender = '', this.bio = '', this.language = 'Español',
    this.photoUrl, this.status = 'active', this.planTier = 'free',
    this.entitlementSource = 'none', this.syncEnabled = false,
    this.birthDate, this.createdAt, this.updatedAt, this.lastLoginAt,
  });

  static const AccountProfile empty = AccountProfile(
    uid: '', email: '', displayName: '', firstName: '', lastName: '',
    username: '', phone: '', country: '', stateProvince: '', city: '',
    address: '', gender: '', bio: '', language: 'Español',
    photoUrl: null, status: 'inactive', planTier: 'free',
  );

  bool get isPro => planTier.toLowerCase() == 'pro' || isBusiness;
  bool get isBusiness => planTier.toLowerCase() == 'business';
  bool get isActive => status.toLowerCase() == 'active';

  int? get calculatedAge {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  AccountProfile copyWith({
    String? uid, String? email, String? displayName, String? firstName,
    String? lastName, String? username, String? phone, String? country,
    String? stateProvince, String? city, String? address, String? gender,
    String? bio, String? language, String? photoUrl, String? status,
    String? planTier, String? entitlementSource, bool? syncEnabled,
    DateTime? birthDate, DateTime? createdAt, DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AccountProfile(
      uid: uid ?? this.uid, email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      phone: phone ?? this.phone, country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city, address: address ?? this.address,
      gender: gender ?? this.gender, bio: bio ?? this.bio,
      language: language ?? this.language,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status, planTier: planTier ?? this.planTier,
      entitlementSource: entitlementSource ?? this.entitlementSource,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid, 'email': email, 'displayName': displayName,
    'firstName': firstName, 'lastName': lastName, 'username': username,
    'phone': phone, 'country': country, 'stateProvince': stateProvince,
    'city': city, 'address': address, 'gender': gender, 'bio': bio,
    'language': language, 'photoUrl': photoUrl, 'status': status,
    'planTier': planTier, 'entitlementSource': entitlementSource,
    'syncEnabled': syncEnabled, 'birthDate': birthDate?.toIso8601String(),
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

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
      displayName: display, firstName: first, lastName: last,
      username: map['username'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? '',
      city: map['city'] as String? ?? '',
      address: map['address'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      language: map['language'] as String? ?? 'Español',
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'active',
      planTier: map['planTier'] as String? ?? 'free',
      entitlementSource: map['entitlementSource'] as String? ?? 'none',
      syncEnabled: map['syncEnabled'] as bool? ?? false,
      birthDate: map['birthDate'] != null ? DateTime.tryParse(map['birthDate'] as String) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'] as String) : null,
      lastLoginAt: map['lastLoginAt'] != null ? DateTime.tryParse(map['lastLoginAt'] as String) : null,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory AccountProfile.fromJson(String source) =>
      AccountProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
