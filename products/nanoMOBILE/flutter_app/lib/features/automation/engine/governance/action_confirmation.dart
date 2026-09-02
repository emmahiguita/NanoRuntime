/// Consentimiento consumible para una única acción dentro de una ejecución.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Representación canónica y estable entre procesos. No usa `hashCode`.
String canonicalFingerprint(Object? value) {
  Object? canonical(Object? input) {
    if (input is Map) {
      final entries =
          input.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return <String, Object?>{
        for (final entry in entries) entry.key: canonical(entry.value),
      };
    }
    if (input is Iterable) {
      return input.map(canonical).toList(growable: false);
    }
    return input;
  }

  return sha256.convert(utf8.encode(jsonEncode(canonical(value)))).toString();
}

String _secureNonce() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

class ActionConfirmation {
  final String executionId;
  final String confirmationId;
  final String planSignature;
  final int stepIndex;
  final String stepId;
  final String actionSignature;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool _consumed;

  ActionConfirmation({
    required this.executionId,
    required this.planSignature,
    required this.stepIndex,
    required this.stepId,
    required this.actionSignature,
    String? confirmationId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool consumed = false,
  }) : confirmationId = confirmationId ?? _secureNonce(),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       expiresAt =
           expiresAt ??
           (createdAt ?? DateTime.now().toUtc()).add(
             const Duration(minutes: 5),
           ),
       _consumed = consumed;

  bool get consumed => _consumed;

  bool get expired => !DateTime.now().toUtc().isBefore(expiresAt);

  bool consumeIfAuthorizes({
    required String executionId,
    required String planSignature,
    required int stepIndex,
    required String stepId,
    required String actionSignature,
    DateTime? now,
  }) {
    final instant = (now ?? DateTime.now()).toUtc();
    if (_consumed || !instant.isBefore(expiresAt)) return false;
    final valid =
        this.executionId == executionId &&
        this.planSignature == planSignature &&
        this.stepIndex == stepIndex &&
        this.stepId == stepId &&
        this.actionSignature == actionSignature;
    if (!valid) return false;
    _consumed = true;
    return true;
  }

  Map<String, Object?> toJson() => {
    'executionId': executionId,
    'confirmationId': confirmationId,
    'planSignature': planSignature,
    'stepIndex': stepIndex,
    'stepId': stepId,
    'actionSignature': actionSignature,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'consumed': _consumed,
  };

  factory ActionConfirmation.fromJson(Map<String, Object?> json) =>
      ActionConfirmation(
        executionId: json['executionId'] as String,
        confirmationId: json['confirmationId'] as String,
        planSignature: json['planSignature'] as String,
        stepIndex: json['stepIndex'] as int,
        stepId: json['stepId'] as String,
        actionSignature: json['actionSignature'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
        consumed: json['consumed'] == true,
      );
}
