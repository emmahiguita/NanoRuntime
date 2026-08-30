/// Journal durable mínimo para ejecución exactly-once de commits irreversibles.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../governance/action_confirmation.dart';
import 'task_plan.dart';

const _interruptionGrace = Duration(minutes: 2);

bool _isActiveCommit(ExecutionJournalStatus status) =>
    status == ExecutionJournalStatus.executing ||
    status == ExecutionJournalStatus.executed ||
    status == ExecutionJournalStatus.verifying;

bool _isFrozenUncertain(ExecutionJournalStatus status) =>
    status == ExecutionJournalStatus.completedUnverified ||
    status == ExecutionJournalStatus.outcomeUnknown;

void _ensureSafeReplacement(
  ExecutionJournalEntry? existing,
  ExecutionJournalEntry replacement,
) {
  if (existing == null || !existing.irreversible) return;
  final replacesFrozen =
      _isFrozenUncertain(existing.status) &&
      (replacement.status != existing.status ||
          replacement.actionSignature != existing.actionSignature);
  final replacesActiveAction =
      _isActiveCommit(existing.status) &&
      (replacement.actionSignature != existing.actionSignature ||
          replacement.status == ExecutionJournalStatus.planned ||
          replacement.status == ExecutionJournalStatus.waitingConfirmation);
  if (replacesFrozen || replacesActiveAction) {
    throw StateError(
      'una transacción irreversible activa o incierta no puede sobrescribirse',
    );
  }
}

enum ExecutionJournalStatus {
  planned,
  waitingConfirmation,
  authorized,
  executing,
  executed,
  verifying,
  verified,
  completedUnverified,
  outcomeUnknown,
  failed,
  cancelled,
}

final class ExecutionJournalEntry {
  final String runId;
  final String planSignature;
  final String goalFingerprint;
  final int currentStep;
  final String stepId;
  final ExecutionJournalStatus status;
  final bool irreversible;
  final String actionSignature;
  final String verificationState;
  final DateTime timestamp;
  final ActionConfirmation? pendingConfirmation;
  final Map<String, RequiredEvidence> evidenceByStep;

  const ExecutionJournalEntry({
    required this.runId,
    required this.planSignature,
    required this.goalFingerprint,
    required this.currentStep,
    required this.stepId,
    required this.status,
    required this.irreversible,
    required this.actionSignature,
    required this.verificationState,
    required this.timestamp,
    this.pendingConfirmation,
    this.evidenceByStep = const {},
  });

  ExecutionJournalEntry copyWith({
    ExecutionJournalStatus? status,
    String? verificationState,
    DateTime? timestamp,
    ActionConfirmation? pendingConfirmation,
    bool clearPendingConfirmation = false,
  }) => ExecutionJournalEntry(
    runId: runId,
    planSignature: planSignature,
    goalFingerprint: goalFingerprint,
    currentStep: currentStep,
    stepId: stepId,
    status: status ?? this.status,
    irreversible: irreversible,
    actionSignature: actionSignature,
    verificationState: verificationState ?? this.verificationState,
    timestamp: timestamp ?? this.timestamp,
    pendingConfirmation: clearPendingConfirmation
        ? null
        : pendingConfirmation ?? this.pendingConfirmation,
    evidenceByStep: evidenceByStep,
  );

  Map<String, Object?> toJson() => {
    'runId': runId,
    'planSignature': planSignature,
    'goalFingerprint': goalFingerprint,
    'currentStep': currentStep,
    'stepId': stepId,
    // Compatibilidad de rollback: una versión anterior interpreta este estado
    // como una confirmación pendiente sin token y, por tanto, falla cerrada.
    'status': status == ExecutionJournalStatus.authorized
        ? ExecutionJournalStatus.waitingConfirmation.name
        : status.name,
    if (status == ExecutionJournalStatus.authorized)
      'authorizationState': ExecutionJournalStatus.authorized.name,
    'irreversible': irreversible,
    'actionSignature': actionSignature,
    'verificationState': verificationState,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'pendingConfirmation': pendingConfirmation?.toJson(),
    'evidenceByStep': {
      for (final entry in evidenceByStep.entries) entry.key: entry.value.name,
    },
  };

  factory ExecutionJournalEntry.fromJson(Map<String, Object?> json) {
    final pending = json['pendingConfirmation'];
    final evidence = json['evidenceByStep'];
    return ExecutionJournalEntry(
      runId: json['runId'] as String,
      planSignature: json['planSignature'] as String,
      goalFingerprint: json['goalFingerprint'] as String,
      currentStep: json['currentStep'] as int,
      stepId: json['stepId'] as String,
      status:
          json['authorizationState'] == ExecutionJournalStatus.authorized.name
          ? ExecutionJournalStatus.authorized
          : ExecutionJournalStatus.values.byName(json['status'] as String),
      irreversible: json['irreversible'] == true,
      actionSignature: json['actionSignature'] as String,
      verificationState: json['verificationState'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      pendingConfirmation: pending is Map
          ? ActionConfirmation.fromJson(
              pending.map((key, value) => MapEntry('$key', value)),
            )
          : null,
      evidenceByStep: evidence is Map
          ? {
              for (final entry in evidence.entries)
                '${entry.key}': RequiredEvidence.values.byName(
                  '${entry.value}',
                ),
            }
          : const {},
    );
  }
}

abstract interface class ExecutionJournal {
  Future<void> save(ExecutionJournalEntry entry);
  Future<ExecutionJournalEntry?> load(String runId);
  Future<List<ExecutionJournalEntry>> all();
  Future<bool> tryBeginIrreversible(ExecutionJournalEntry entry);
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  );
  Future<void> recoverInterrupted();
}

ExecutionJournalEntry? _consumePendingConfirmation(
  ExecutionJournalEntry? entry,
  ActionConfirmation presented,
) {
  if (entry == null ||
      entry.status != ExecutionJournalStatus.waitingConfirmation) {
    return null;
  }
  final pending = entry.pendingConfirmation;
  if (pending == null || pending.confirmationId != presented.confirmationId) {
    return null;
  }
  final consumed = pending.consumeIfAuthorizes(
    executionId: presented.executionId,
    planSignature: presented.planSignature,
    stepIndex: presented.stepIndex,
    stepId: presented.stepId,
    actionSignature: presented.actionSignature,
  );
  if (!consumed) return null;
  return entry.copyWith(
    status: ExecutionJournalStatus.authorized,
    verificationState: 'confirmación consumida; acción aún no iniciada',
    timestamp: DateTime.now().toUtc(),
    clearPendingConfirmation: true,
  );
}

final class SharedPreferencesExecutionJournal implements ExecutionJournal {
  static const _storeKey = 'nano.executionJournal.store.v2';
  static const _indexKey = 'nano.executionJournal.index.v1';
  static const _entryPrefix = 'nano.executionJournal.entry.v1.';
  static const _maxTerminalEntries = 128;
  static Future<void> _storageQueue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _storageQueue;
    final release = Completer<void>();
    _storageQueue = release.future;
    await previous;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }

  Map<String, ExecutionJournalEntry> _decodeStore(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final entries = <String, ExecutionJournalEntry>{};
      for (final item in decoded.entries) {
        if (item.value is! Map) continue;
        try {
          final entry = ExecutionJournalEntry.fromJson(
            (item.value as Map).map((key, value) => MapEntry('$key', value)),
          );
          entries[entry.runId] = entry;
        } on Object {
          // Una entrada corrupta no invalida las demás transacciones.
        }
      }
      return entries;
    } on Object {
      return {};
    }
  }

  Future<Map<String, ExecutionJournalEntry>> _readLegacy(
    SharedPreferences prefs,
  ) async {
    final entries = <String, ExecutionJournalEntry>{};
    final ids = prefs.getStringList(_indexKey) ?? const <String>[];
    for (final id in ids) {
      final raw = prefs.getString('$_entryPrefix$id');
      if (raw == null) continue;
      try {
        final entry = ExecutionJournalEntry.fromJson(
          (jsonDecode(raw) as Map).map((key, value) => MapEntry('$key', value)),
        );
        entries[entry.runId] = entry;
      } on Object {
        // Compatibilidad: ignorar únicamente la entrada legacy corrupta.
      }
    }
    return entries;
  }

  Future<Map<String, ExecutionJournalEntry>> _readAllUnlocked(
    SharedPreferences prefs,
  ) async {
    final entries = await _readLegacy(prefs);
    entries.addAll(_decodeStore(prefs.getString(_storeKey)));
    return entries;
  }

  Future<void> _writeAllUnlocked(
    SharedPreferences prefs,
    Map<String, ExecutionJournalEntry> entries,
  ) async {
    _pruneTerminalEntries(entries);
    final encoded = jsonEncode({
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    });
    final persisted = await prefs.setString(_storeKey, encoded);
    if (!persisted) {
      throw StateError('no fue posible persistir el execution journal');
    }
  }

  void _pruneTerminalEntries(Map<String, ExecutionJournalEntry> entries) {
    final terminal =
        entries.values
            .where(
              (entry) =>
                  entry.status == ExecutionJournalStatus.verified ||
                  entry.status == ExecutionJournalStatus.failed ||
                  entry.status == ExecutionJournalStatus.cancelled,
            )
            .toList(growable: false)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (final entry in terminal.skip(_maxTerminalEntries)) {
      entries.remove(entry.runId);
    }
  }

  Future<void> _saveUnlocked(
    SharedPreferences prefs,
    ExecutionJournalEntry entry,
  ) async {
    final entries = await _readAllUnlocked(prefs);
    _ensureSafeReplacement(entries[entry.runId], entry);
    entries[entry.runId] = entry;
    await _writeAllUnlocked(prefs, entries);
  }

  @override
  Future<void> save(ExecutionJournalEntry entry) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    await _saveUnlocked(prefs, entry);
  });

  @override
  Future<ExecutionJournalEntry?> load(String runId) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _readAllUnlocked(prefs))[runId];
  });

  @override
  Future<List<ExecutionJournalEntry>> all() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    return List.unmodifiable((await _readAllUnlocked(prefs)).values);
  });

  @override
  Future<bool> tryBeginIrreversible(ExecutionJournalEntry entry) => _serialized(
    () async {
      if (!entry.irreversible ||
          entry.status != ExecutionJournalStatus.executing) {
        throw ArgumentError(
          'tryBeginIrreversible requiere una entrada irreversible/executing',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final entries = await _readAllUnlocked(prefs);
      final sameRun = entries[entry.runId];
      if (sameRun == null ||
          !sameRun.irreversible ||
          sameRun.status != ExecutionJournalStatus.authorized ||
          sameRun.planSignature != entry.planSignature ||
          sameRun.currentStep != entry.currentStep ||
          sameRun.stepId != entry.stepId ||
          sameRun.actionSignature != entry.actionSignature) {
        return false;
      }
      final blocked = entries.values.any(
        (existing) =>
            existing.runId != entry.runId &&
            existing.irreversible &&
            existing.actionSignature == entry.actionSignature &&
            (existing.status == ExecutionJournalStatus.executing ||
                existing.status == ExecutionJournalStatus.executed ||
                existing.status == ExecutionJournalStatus.verifying ||
                existing.status == ExecutionJournalStatus.completedUnverified ||
                existing.status == ExecutionJournalStatus.outcomeUnknown),
      );
      if (blocked) return false;
      entries[entry.runId] = entry;
      await _writeAllUnlocked(prefs, entries);
      return true;
    },
  );

  @override
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  ) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readAllUnlocked(prefs);
    final claimed = _consumePendingConfirmation(
      entries[confirmation.executionId],
      confirmation,
    );
    if (claimed == null) return null;
    await _saveUnlocked(prefs, claimed);
    return claimed;
  });

  @override
  Future<void> recoverInterrupted() async {
    final staleBefore = DateTime.now().toUtc().subtract(_interruptionGrace);
    for (final entry in await all()) {
      final abandonedBeforeExecution =
          (entry.status == ExecutionJournalStatus.waitingConfirmation &&
              (entry.pendingConfirmation == null ||
                  entry.pendingConfirmation!.expired)) ||
          (entry.status == ExecutionJournalStatus.authorized &&
              entry.timestamp.isBefore(staleBefore));
      if (abandonedBeforeExecution) {
        await save(
          entry.copyWith(
            status: ExecutionJournalStatus.cancelled,
            verificationState:
                'intención expirada antes de iniciar; no hubo efecto externo',
            timestamp: DateTime.now().toUtc(),
            clearPendingConfirmation: true,
          ),
        );
        continue;
      }
      final interrupted =
          entry.irreversible &&
          entry.timestamp.isBefore(staleBefore) &&
          (entry.status == ExecutionJournalStatus.executing ||
              entry.status == ExecutionJournalStatus.executed ||
              entry.status == ExecutionJournalStatus.verifying);
      if (!interrupted) continue;
      await save(
        entry.copyWith(
          status: ExecutionJournalStatus.outcomeUnknown,
          verificationState:
              'proceso interrumpido durante commit; requiere reconciliación',
          timestamp: DateTime.now().toUtc(),
        ),
      );
    }
  }
}

final class InMemoryExecutionJournal implements ExecutionJournal {
  final Map<String, ExecutionJournalEntry> _entries = {};

  @override
  Future<void> save(ExecutionJournalEntry entry) async {
    _ensureSafeReplacement(_entries[entry.runId], entry);
    _entries[entry.runId] = entry;
  }

  @override
  Future<ExecutionJournalEntry?> load(String runId) async => _entries[runId];

  @override
  Future<List<ExecutionJournalEntry>> all() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<bool> tryBeginIrreversible(ExecutionJournalEntry entry) async {
    if (!entry.irreversible ||
        entry.status != ExecutionJournalStatus.executing) {
      throw ArgumentError(
        'tryBeginIrreversible requiere una entrada irreversible/executing',
      );
    }
    final blocked = _entries.values.any(
      (existing) =>
          existing.runId != entry.runId &&
          existing.irreversible &&
          existing.actionSignature == entry.actionSignature &&
          (existing.status == ExecutionJournalStatus.executing ||
              existing.status == ExecutionJournalStatus.executed ||
              existing.status == ExecutionJournalStatus.verifying ||
              existing.status == ExecutionJournalStatus.completedUnverified ||
              existing.status == ExecutionJournalStatus.outcomeUnknown),
    );
    final sameRun = _entries[entry.runId];
    if (blocked ||
        sameRun == null ||
        !sameRun.irreversible ||
        sameRun.status != ExecutionJournalStatus.authorized ||
        sameRun.planSignature != entry.planSignature ||
        sameRun.currentStep != entry.currentStep ||
        sameRun.stepId != entry.stepId ||
        sameRun.actionSignature != entry.actionSignature) {
      return false;
    }
    _entries[entry.runId] = entry;
    return true;
  }

  @override
  Future<ExecutionJournalEntry?> consumeConfirmation(
    ActionConfirmation confirmation,
  ) async {
    final claimed = _consumePendingConfirmation(
      _entries[confirmation.executionId],
      confirmation,
    );
    if (claimed == null) return null;
    _entries[claimed.runId] = claimed;
    return claimed;
  }

  @override
  Future<void> recoverInterrupted() async {
    final staleBefore = DateTime.now().toUtc().subtract(_interruptionGrace);
    for (final entry in [..._entries.values]) {
      final abandonedBeforeExecution =
          (entry.status == ExecutionJournalStatus.waitingConfirmation &&
              (entry.pendingConfirmation == null ||
                  entry.pendingConfirmation!.expired)) ||
          (entry.status == ExecutionJournalStatus.authorized &&
              entry.timestamp.isBefore(staleBefore));
      if (abandonedBeforeExecution) {
        await save(
          entry.copyWith(
            status: ExecutionJournalStatus.cancelled,
            verificationState: 'intención expirada antes de iniciar',
            timestamp: DateTime.now().toUtc(),
            clearPendingConfirmation: true,
          ),
        );
        continue;
      }
      final interrupted =
          entry.irreversible &&
          entry.timestamp.isBefore(staleBefore) &&
          (entry.status == ExecutionJournalStatus.executing ||
              entry.status == ExecutionJournalStatus.executed ||
              entry.status == ExecutionJournalStatus.verifying);
      if (interrupted) {
        await save(
          entry.copyWith(
            status: ExecutionJournalStatus.outcomeUnknown,
            verificationState: 'interrumpido',
            timestamp: DateTime.now().toUtc(),
          ),
        );
      }
    }
  }
}
