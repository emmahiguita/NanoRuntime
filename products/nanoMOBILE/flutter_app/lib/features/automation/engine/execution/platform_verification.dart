/// A14.5 — Verificación de resultado por PLATAFORMA.
///
/// Distinción central:
///   EXECUTION SUCCESS  !=  ACTION VERIFIED  !=  GOAL SATISFIED
///
/// El ActionVerifier verifica postcondiciones de UI (snapshot de accesibilidad).
/// Este módulo añade postcondiciones de PLATAFORMA tipadas: hechos que se
/// comprueban contra el estado real del sistema (app en primer plano, archivo
/// existente, proceso ausente, ...), no contra lo que el backend "devolvió OK".
///
/// No crea un segundo sistema de verdad: ActionVerifier/GoalVerifier siguen
/// siendo los verificadores; este módulo aporta predicados que ellos evalúan a
/// través de [PlatformStateReader] (DIP).
library;

/// Postcondición de plataforma tipada. Sealed: el lector decide por tipo sin
/// switches de strings.
sealed class PlatformPredicate {
  const PlatformPredicate();

  /// Descripción legible para traces/feedback.
  String toDebugString();
}

/// La app indicada queda en primer plano tras la acción (ej. launch_app).
class ForegroundPackageEquals extends PlatformPredicate {
  const ForegroundPackageEquals(this.packageName);
  final String packageName;
  @override
  String toDebugString() => 'foregroundPkg==$packageName';
}

/// La app indicada ya NO está en primer plano (ej. force_stop / back).
class PackageNotForeground extends PlatformPredicate {
  const PackageNotForeground(this.packageName);
  final String packageName;
  @override
  String toDebugString() => 'notForegroundPkg==$packageName';
}

/// El proceso del paquete indicado no está en ejecución (fuerza real de stop).
class PackageProcessAbsent extends PlatformPredicate {
  const PackageProcessAbsent(this.packageName);
  final String packageName;
  @override
  String toDebugString() => 'processAbsent==$packageName';
}

/// El comando Linux terminó con el código de salida esperado.
class ProcessExitCodeEquals extends PlatformPredicate {
  const ProcessExitCodeEquals(this.exitCode);
  final int exitCode;
  @override
  String toDebugString() => 'exitCode==$exitCode';
}

/// El archivo existe en la ruta indicada (verificación de escritura Linux).
class FileExists extends PlatformPredicate {
  const FileExists(this.path);
  final String path;
  @override
  String toDebugString() => 'fileExists==$path';
}

/// El archivo contiene el texto esperado (contenido/estado, no solo existencia).
class FileContentContains extends PlatformPredicate {
  const FileContentContains(this.path, this.content);
  final String path;
  final String content;
  @override
  String toDebugString() => 'fileContains==$path';
}

/// La respuesta a la notificación fue ACEPTADA por RemoteInput.
/// Honestidad: esto demuestra despacho aceptado, NO lectura ni entrega.
class NotificationReplyAccepted extends PlatformPredicate {
  const NotificationReplyAccepted(this.key);
  final String key;
  @override
  String toDebugString() => 'replyAccepted==$key';
}

/// A14.5.4 — predicados de ESTADO SEMÁNTICO (el objetivo real del usuario,
/// no solo "llegué al destino"). Distinguen "pantalla contiene X" de "el
/// estado X ocurrió".

/// Reproducción de medios activa/inactiva (reproduce/pausa un video/audio).
class MediaPlaybackStateEquals extends PlatformPredicate {
  const MediaPlaybackStateEquals(this.playing);
  final bool playing;
  @override
  String toDebugString() => 'mediaPlaying==$playing';
}

/// Conmutador de sistema en un estado concreto (Bluetooth/WiFi on/off).
enum SystemToggle { bluetooth, wifi }

class ToggleStateEquals extends PlatformPredicate {
  const ToggleStateEquals(this.toggle, this.enabled);
  final SystemToggle toggle;
  final bool enabled;
  @override
  String toDebugString() => '${toggle.name}==$enabled';
}

/// Un campo de texto (EditText) contiene el texto esperado (estado real de la
/// UI, no presencia de un label). Se resuelve contra el snapshot de accesibilidad.
class TextFieldContains extends PlatformPredicate {
  const TextFieldContains(this.text, {this.caseSensitive = false});
  final String text;
  final bool caseSensitive;
  @override
  String toDebugString() => 'fieldContains==$text';
}

/// Conversación abierta (package en primer plano + evidencia de conversación).
/// En la práctica se resuelve como [ForegroundPackageEquals] cuando el package
/// de la app de mensajería es el esperado; el id exacto de conversación no es
/// observable de forma fiable en Android moderno.
class ConversationOpenEquals extends PlatformPredicate {
  const ConversationOpenEquals(this.packageName, this.conversationId);
  final String packageName;
  final String conversationId;
  @override
  String toDebugString() => 'conversationOpen==$conversationId@$packageName';
}

/// Veredicto de la evaluación de un predicado de plataforma.
sealed class PlatformPredicateResult {
  const PlatformPredicateResult();
}

/// El hecho se cumple (con evidencia legible).
class PlatformPredicateSatisfied extends PlatformPredicateResult {
  const PlatformPredicateSatisfied([this.evidence = '']);
  final String evidence;
}

/// El hecho NO se cumple (veredicto real, no "OK").
class PlatformPredicateUnsatisfied extends PlatformPredicateResult {
  const PlatformPredicateUnsatisfied(this.reason);
  final String reason;
}

/// El hecho no puede observarse con la infraestructura actual (honesto).
/// Ej: visibilidad de procesos restringida en Android moderno.
class PlatformPredicateUnavailable extends PlatformPredicateResult {
  const PlatformPredicateUnavailable(this.reason);
  final String reason;
}

/// Lector de estado de plataforma (DIP). El ActionVerifier depende de esta
/// interfaz, NO de MethodChannel/Process/PackageManager/Shizuku.
abstract interface class PlatformStateReader {
  Future<PlatformPredicateResult> evaluate(PlatformPredicate predicate);
}

/// Composición mínima: TODOS los predicados deben cumplirse. Si cualquiera es
/// unsatisfied/unavailable, el resultado refleja el primero (en orden).
Future<PlatformPredicateResult> evaluateAllOf(
  List<PlatformPredicate> predicates,
  PlatformStateReader reader,
) async {
  for (final predicate in predicates) {
    final r = await reader.evaluate(predicate);
    if (r is! PlatformPredicateSatisfied) return r;
  }
  return PlatformPredicateSatisfied('${predicates.length} sub-predicado(s)');
}
