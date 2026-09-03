/// CAP-ROUTER-01 — CapabilityPathPolicy: la POLÍTICA de preferencia de vías
/// por tipo de intento. Vive en un `const` auditado y explicado: ningún
/// número mágico, ninguna decisión implícita.
///
/// Principio rector (ToolCUA adaptado a Nano): la vía más VERIFICABLE gana,
/// no la más rápida. Cada preferencia documenta POR QUÉ.
library;

import 'capability_intent.dart';
import 'execution_path.dart';

/// Preferencias de ruta por tipo de intento, de mejor a peor.
/// Listas `const`: auditable, sin estado, sin LLM.
abstract final class CapabilityPathPolicy {
  /// Para enviar una respuesta:
  ///
  /// 1. remoteInput — la notificación observada nos dio la capacidad EXACTA
  ///    (ReplyCapabilityRef con resultKey real). Sin gestos, sin abrir la
  ///    app, destinatario grounded por la propia notificación. Evidencia
  ///    física WA-PHYS-11: funciona con WhatsApp cerrado.
  /// 2. accessibilityGui — solo cuando NO hay RemoteInput y la conversación
  ///    exacta está abierta en pantalla: cada tap pasa por CommitGuard y el
  ///    envío queda con evidencia pre/post. Más pasos = más superficie de
  ///    fallo, por eso pierde contra RemoteInput.
  /// 3. none — sin evidencia suficiente: fail-closed.
  static const List<ExecutionPath> replyPreference = [
    ExecutionPath.remoteInput,
    ExecutionPath.accessibilityGui,
  ];

  /// Para abrir una conversación:
  ///
  /// 1. androidIntent — lanzar la app por intent del sistema es un efecto
  ///    nativo, verificable con dumpsys/foreground, sin gestos.
  /// 2. accessibilityGui — navegación interna (búsqueda + tap en la
  ///    conversación) solo cuando la app ya está abierta y el perfil de
  ///    superficie declara los elementos necesarios.
  /// 3. none — sin evidencia suficiente: fail-closed.
  static const List<ExecutionPath> openConversationPreference = [
    ExecutionPath.androidIntent,
    ExecutionPath.accessibilityGui,
  ];

  /// Preferencias para un intento dado. Devuelve lista vacía si el tipo de
  /// intento no está cubierto por la política (honesto: mejor vacío que
  /// inventar).
  static List<ExecutionPath> preferenceFor(CapabilityIntent intent) =>
      switch (intent) {
        ReplyIntent() => replyPreference,
        OpenConversationIntent() => openConversationPreference,
      };
}
