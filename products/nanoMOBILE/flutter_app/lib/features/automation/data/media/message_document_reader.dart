import 'dart:async';
import 'package:flutter/services.dart';
import '../../../../core/services/execution_budget.dart';

/// QUÉ: lleva archivos del mensaje al lector nativo local, también sin Activity.
/// CÓMO: cada solicitud tiene ID y plazo; timeout cancela su trabajo nativo.
/// POR QUÉ: dejar de esperar un Future no basta para detener un PDF en proceso.
final class MessageDocumentReader {
  static const channel = MethodChannel('dev.nanoai/pdf_text');
  static int _sequence = 0;

  Future<Map<String, dynamic>> read(String path, {required bool image}) async {
    final id =
        'message:${DateTime.now().microsecondsSinceEpoch}:${_sequence++}';
    void cancel() {
      unawaited(
        channel
            .invokeMethod<void>('cancel', {'requestId': id})
            .catchError((Object _) {}),
      );
    }

    final detach = ExecutionBudget.current?.register(cancel);
    try {
      final result = await channel
          .invokeMapMethod<String, dynamic>(
            image ? 'readMessageImage' : 'readMessagePdf',
            {'path': path, 'requestId': id},
          )
          .timeout(
            const Duration(seconds: 22),
            onTimeout: () {
              cancel();
              throw TimeoutException('Lectura multimedia agotada');
            },
          );
      ExecutionBudget.current?.check();
      return result ?? const {};
    } finally {
      detach?.call();
    }
  }
}
