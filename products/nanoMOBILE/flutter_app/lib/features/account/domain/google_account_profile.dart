import 'dart:convert';

/// Perfil de cuenta de Google vinculada en Nano AI.
///
/// Representa la identidad real del usuario autenticado y los servicios web
/// que se ejecutan directamente a través de sesiones de navegador y MCP (sin API Keys).
class GoogleAccountProfile {
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isConnected;
  final bool isInternetReachable;
  final DateTime? lastSynced;
  final bool browserAgentEnabled;
  final bool googleSearchEnabled;
  final bool cloudSyncEnabled;
  final String syncStatus;

  const GoogleAccountProfile({
    this.email = '',
    this.displayName = '',
    this.avatarUrl,
    this.isConnected = false,
    this.isInternetReachable = false,
    this.lastSynced,
    this.browserAgentEnabled = false,
    this.googleSearchEnabled = false,
    this.cloudSyncEnabled = false,
    this.syncStatus = 'No configurada',
  });

  const GoogleAccountProfile.unconfigured()
    : email = '',
      displayName = '',
      avatarUrl = null,
      isConnected = false,
      isInternetReachable = false,
      lastSynced = null,
      browserAgentEnabled = false,
      googleSearchEnabled = false,
      cloudSyncEnabled = false,
      syncStatus = 'No configurada';

  /// Iniciales del usuario para el avatar en caso de no contar con foto URL.
  String get initials {
    if (displayName.trim().isEmpty) {
      return email.isNotEmpty ? email.substring(0, 1).toUpperCase() : '?';
    }
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final p1 = parts[0].isNotEmpty ? parts[0][0] : '';
      final p2 = parts[1].isNotEmpty ? parts[1][0] : '';
      return (p1 + p2).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  GoogleAccountProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isConnected,
    bool? isInternetReachable,
    DateTime? lastSynced,
    bool? browserAgentEnabled,
    bool? googleSearchEnabled,
    bool? cloudSyncEnabled,
    String? syncStatus,
  }) {
    return GoogleAccountProfile(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isConnected: isConnected ?? this.isConnected,
      isInternetReachable: isInternetReachable ?? this.isInternetReachable,
      lastSynced: lastSynced ?? this.lastSynced,
      browserAgentEnabled: browserAgentEnabled ?? this.browserAgentEnabled,
      googleSearchEnabled: googleSearchEnabled ?? this.googleSearchEnabled,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isConnected': isConnected,
      'isInternetReachable': isInternetReachable,
      'lastSynced': lastSynced?.toIso8601String(),
      'browserAgentEnabled': browserAgentEnabled,
      'googleSearchEnabled': googleSearchEnabled,
      'cloudSyncEnabled': cloudSyncEnabled,
      'syncStatus': syncStatus,
    };
  }

  factory GoogleAccountProfile.fromMap(Map<String, dynamic> map) {
    return GoogleAccountProfile(
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      isConnected: map['isConnected'] as bool? ?? false,
      isInternetReachable: map['isInternetReachable'] as bool? ?? false,
      lastSynced: map['lastSynced'] != null
          ? DateTime.tryParse(map['lastSynced'] as String)
          : null,
      browserAgentEnabled: map['browserAgentEnabled'] as bool? ?? false,
      googleSearchEnabled: map['googleSearchEnabled'] as bool? ?? false,
      cloudSyncEnabled: map['cloudSyncEnabled'] as bool? ?? false,
      syncStatus: map['syncStatus'] as String? ?? 'No configurada',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GoogleAccountProfile.fromJson(String source) =>
      GoogleAccountProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
