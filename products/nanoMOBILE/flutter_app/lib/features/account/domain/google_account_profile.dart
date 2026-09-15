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
  final DateTime? lastSynced;
  final bool browserAgentEnabled;
  final bool googleSearchEnabled;
  final bool cloudSyncEnabled;
  final String syncStatus;

  const GoogleAccountProfile({
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isConnected = true,
    this.lastSynced,
    this.browserAgentEnabled = true,
    this.googleSearchEnabled = true,
    this.cloudSyncEnabled = true,
    this.syncStatus = 'Sesión Activa (Navegador)',
  });

  /// Iniciales del usuario para el avatar en caso de no contar con foto URL.
  String get initials {
    if (displayName.trim().isEmpty) {
      return email.isNotEmpty ? email.substring(0, 1).toUpperCase() : 'G';
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
      'lastSynced': lastSynced?.toIso8601String(),
      'browserAgentEnabled': browserAgentEnabled,
      'googleSearchEnabled': googleSearchEnabled,
      'cloudSyncEnabled': cloudSyncEnabled,
      'syncStatus': syncStatus,
    };
  }

  factory GoogleAccountProfile.fromMap(Map<String, dynamic> map) {
    return GoogleAccountProfile(
      email: map['email'] as String? ?? 'emmanuel.higuita.gomez@gmail.com',
      displayName: map['displayName'] as String? ?? 'Emmanuel Higuita',
      avatarUrl: map['avatarUrl'] as String?,
      isConnected: map['isConnected'] as bool? ?? true,
      lastSynced: map['lastSynced'] != null
          ? DateTime.tryParse(map['lastSynced'] as String)
          : DateTime.now(),
      browserAgentEnabled: map['browserAgentEnabled'] as bool? ?? true,
      googleSearchEnabled: map['googleSearchEnabled'] as bool? ?? true,
      cloudSyncEnabled: map['cloudSyncEnabled'] as bool? ?? true,
      syncStatus: map['syncStatus'] as String? ?? 'Sesión Activa (Navegador)',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GoogleAccountProfile.fromJson(String source) =>
      GoogleAccountProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
