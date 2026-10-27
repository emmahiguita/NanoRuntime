import 'dart:async';

import 'package:flutter/foundation.dart';

/// Serializa escrituras de memoria y registra etapa, causa y profundidad de cola.
class ConversationPersistenceQueue {
  ConversationPersistenceQueue({required this.lastStoreError});

  final String? Function() lastStoreError;
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Reintenta tres veces como máximo; así no deja trabajos infinitos bloqueando memoria.
  Future<bool> run(
    String phase,
    Future<bool> Function() operation, {
    bool rethrowAfterRetries = false,
  }) {
    _pending++;
    final result = _tail.then<bool>((_) async {
      Object? lastFailure;
      StackTrace? lastStack;
      var lastAttemptThrew = false;
      try {
        for (var attempt = 1; attempt <= 3; attempt++) {
          try {
            if (await operation()) return true;
            lastFailure = StateError(
              lastStoreError() ?? 'El almacén rechazó la escritura.',
            );
            lastStack = null;
            lastAttemptThrew = false;
          } catch (error, stackTrace) {
            lastFailure = error;
            lastStack = stackTrace;
            lastAttemptThrew = true;
          }
          if (attempt < 3) {
            await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
          }
        }
        debugPrint(
          '[conversation-memory][$phase] failed attempts=3 pending=$_pending cause=$lastFailure',
        );
        if (lastStack != null) debugPrintStack(stackTrace: lastStack);
        if (rethrowAfterRetries && lastAttemptThrew && lastFailure != null) {
          Error.throwWithStackTrace(lastFailure, lastStack!);
        }
        return false;
      } finally {
        _pending--;
      }
    });
    // Aísla fallos inesperados para que la siguiente escritura todavía pueda ejecutarse.
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[conversation-memory][queue] ${error.runtimeType}: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    return result;
  }
}
