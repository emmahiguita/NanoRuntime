/// ROLE-01 — AssistantRoleManager: gestión EXPLÍCITA del role de asistente
/// (ROLE_ASSISTANT, API 29+). La base nativa ya existía
/// (NanoVoiceInteractionService + BIND_VOICE_INTERACTION en el manifest);
/// este archivo es el puente Dart + el contrato de uso.
///
/// Reglas duras:
/// - NUNCA se solicita automáticamente: [requestRole] solo se invoca desde
///   un botón explícito del usuario. Abre el selector del sistema, jamás
///   fuerza la concesión.
/// - Negar no rompe nada: [isHoldingRole] sigue false y no hay reintentos
///   silenciosos (estado honesto en la UI).
/// - [isHoldingRole] e [isSessionActive] son consultas pasivas: no abren
///   diálogos.
///
/// [isSessionActive] llena el AssistContext que EDGE-02 dejó declarado: la
/// sesión viva se observa en NanoVoiceInteractionSession (contador de
/// onCreate/onDestroy), jamás se inventa.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AssistantRoleManager {
  /// Consulta pasiva: ¿Nano es el asistente seleccionado AHORA?
  Future<bool> isHoldingRole();

  /// Consulta pasiva: ¿hay una sesión de asistente activa AHORA?
  Future<bool> isSessionActive();

  /// Abre el diálogo del sistema para solicitar el role. Devuelve true si
  /// el selector se lanzó (no si el usuario aceptó). Solo botón explícito.
  Future<bool> requestRole();
}

/// Implementación sobre el canal nativo `com.nanoai/assistant_role`
/// (AssistantRoleChannelHandler). Cualquier fallo de canal = false
/// (honestamente no disponible), nunca lanza.
final class MethodChannelAssistantRoleManager implements AssistantRoleManager {
  MethodChannelAssistantRoleManager({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.nanoai/assistant_role');

  final MethodChannel _channel;

  @override
  Future<bool> isHoldingRole() => _bool('isHoldingRole');

  @override
  Future<bool> isSessionActive() => _bool('isSessionActive');

  @override
  Future<bool> requestRole() => _bool('requestRole');

  Future<bool> _bool(String method) async {
    try {
      final value = await _channel.invokeMethod<bool>(method);
      return value ?? false;
    } on Object {
      return false;
    }
  }
}

/// Instancia única del manager de role (canal nativo).
final assistantRoleManagerProvider = Provider<AssistantRoleManager>((ref) {
  return MethodChannelAssistantRoleManager();
});
