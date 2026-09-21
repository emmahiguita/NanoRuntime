import 'dart:convert';

/// QUÉ HACE:
/// Representa un dispositivo vinculado a la cuenta Nano (Mobile, Desktop, Web).
///
/// CÓMO FUNCIONA:
/// Almacena un identificador seguro generado aleatoriamente (UUID v4) por instalación,
/// nombre amigable del dispositivo y fecha de último acceso. No usa IMEI ni Android ID.
///
/// POR QUÉ:
/// Cumple con las políticas de privacidad de Google Play y arquitectura multi-dispositivo.
class DeviceEntity {
  final String deviceId;
  final String friendlyName;
  final String platform; // android, linux, windows, macos, web
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCurrentDevice;

  const DeviceEntity({
    required this.deviceId,
    required this.friendlyName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    this.isCurrentDevice = false,
  });

  DeviceEntity copyWith({
    String? deviceId,
    String? friendlyName,
    String? platform,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    bool? isCurrentDevice,
  }) {
    return DeviceEntity(
      deviceId: deviceId ?? this.deviceId,
      friendlyName: friendlyName ?? this.friendlyName,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isCurrentDevice: isCurrentDevice ?? this.isCurrentDevice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'friendlyName': friendlyName,
      'platform': platform,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
    };
  }

  factory DeviceEntity.fromMap(
    Map<String, dynamic> map, {
    bool isCurrentDevice = false,
  }) {
    return DeviceEntity(
      deviceId: map['deviceId'] as String? ?? '',
      friendlyName: map['friendlyName'] as String? ?? 'Dispositivo Nano',
      platform: map['platform'] as String? ?? 'android',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastSeenAt: map['lastSeenAt'] != null
          ? DateTime.tryParse(map['lastSeenAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isCurrentDevice: isCurrentDevice,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DeviceEntity.fromJson(
    String source, {
    bool isCurrentDevice = false,
  }) => DeviceEntity.fromMap(
    jsonDecode(source) as Map<String, dynamic>,
    isCurrentDevice: isCurrentDevice,
  );
}
