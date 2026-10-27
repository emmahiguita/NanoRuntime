// QUÉ: identifica si este isolate pertenece a la UI o al servicio sin pantalla.
// CÓMO: consulta una vez el canal que solo registra AutomationRuntimeService.
// POR QUÉ: ambos consumidores necesitan la misma identidad, sin imports cíclicos.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _headlessChannel = MethodChannel('com.nanoai/headless');
Future<bool>? _engineKind;

// Mantiene la API pública previa y comparte su resultado dentro de este engine.
Future<bool> isHeadlessAutomationEngine() =>
    _engineKind ??= _detectHeadlessEngine();

Future<bool> _detectHeadlessEngine() async {
  try {
    return await _headlessChannel
            .invokeMethod<bool>('isHeadless')
            .timeout(const Duration(milliseconds: 1500)) ==
        true;
  } on Object {
    // La UI no registra este canal: conserva el resultado false previo.
    return false;
  }
}

// QUÉ: evita que la UI suspendida compita por notificaciones con el servicio.
// CÓMO: permite al headless recuperar siempre, y a la UI solo estando resumed.
// POR QUÉ: tener una suscripción Dart viva no demuestra propiedad del canal nativo.
Future<bool> canRecoverNotificationBacklog() async =>
    await isHeadlessAutomationEngine() ||
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
