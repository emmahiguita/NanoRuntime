import 'package:flutter/foundation.dart';

/// Estado operativo de una sesión web con un proveedor de IA.
enum BrowserAiSessionStatus {
  idle,
  submitting,
  streaming,
  completed,
  userActionRequired,
  failed,
}

/// QUÉ HACE:
/// Mantiene el estado inmutable de una sesión activa de un proveedor en el navegador.
///
/// CÓMO FUNCIONA:
/// Asocia el ID del proveedor con el identificador de la pestaña ([tabId])
/// en [browserTabProvider], su estado de autenticación y última actividad.
///
/// POR QUÉ:
/// Permite reutilizar pestañas existentes y previene sobreescribir la pestaña
/// de navegación activa del usuario (Clean Architecture).
@immutable
class BrowserAiSession {
  final String providerId;
  final String? tabId;
  final bool isLoggedIn;
  final BrowserAiSessionStatus status;
  final DateTime lastActive;
  final String? lastResponse;

  const BrowserAiSession({
    required this.providerId,
    this.tabId,
    this.isLoggedIn = false,
    this.status = BrowserAiSessionStatus.idle,
    required this.lastActive,
    this.lastResponse,
  });

  BrowserAiSession copyWith({
    String? tabId,
    bool? isLoggedIn,
    BrowserAiSessionStatus? status,
    DateTime? lastActive,
    String? lastResponse,
  }) {
    return BrowserAiSession(
      providerId: providerId,
      tabId: tabId ?? this.tabId,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      status: status ?? this.status,
      lastActive: lastActive ?? this.lastActive,
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }

  @override
  String toString() =>
      'BrowserAiSession($providerId, tab: $tabId, loggedIn: $isLoggedIn, status: ${status.name})';
}
