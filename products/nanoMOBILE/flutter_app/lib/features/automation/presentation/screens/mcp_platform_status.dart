import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

/// Lee únicamente el estado del servicio: no pide permisos ni controla pantallas.
/// Sin respuesta se conserva desconocido, en lugar de deducir un estado activo.
final mcpAccessibilityStatusProvider = FutureProvider.autoDispose<bool?>((
  ref,
) async {
  final status = await NanoRuntimeApi.instance.agentStatus();
  final connected = status?['connected'];
  return connected is bool ? connected : null;
});
