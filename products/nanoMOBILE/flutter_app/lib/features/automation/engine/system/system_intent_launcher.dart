/// SystemIntentLauncher (A3) — frontera de EJECUCIÓN de navegación de sistema.
///
/// ISP: [SystemInventory] lee facts; [SystemIntentLauncher] ejecuta navegación.
/// Son contratos separados. La implementación MethodChannel vive en platform; el
/// executor nativo solo acepta destinos allowlisted (nunca un string crudo de
/// Intent ni un component name arbitrario).
library;

import 'system_destination.dart';

/// Fallo tipado del launcher. Nunca `Exception("falló")` genérico en dominio.
enum SystemIntentError { unsupported, launchFailed, unavailable }

class SystemIntentResult {
  final bool opened;
  final SystemIntentError? error;
  final String reason;

  const SystemIntentResult.ok() : opened = true, error = null, reason = '';

  const SystemIntentResult.failure(this.error, this.reason) : opened = false;
}

/// Ejecuta navegación de sistema hacia un [SystemDestination] semántico.
abstract interface class SystemIntentLauncher {
  Future<SystemIntentResult> open(SystemDestination destination);
}
